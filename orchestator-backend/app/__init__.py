"""App package initializer."""
import json
import websockets
from app.utils import color_style
from app.core.config import settings
from app.core.database import AsyncSessionLocal
from app.services import db_service
from app.schemas.entity import EntityUpdate
from datetime import datetime

ws_url = settings.ha_websocket_url
token = settings.ha_token

# Will be set by startup event in main.py
ws_manager = None


async def listen_homeassistant():
    """Listen to Home Assistant WebSocket events and sync with DB entities."""
    # Load tracked entities from DB service
    async with AsyncSessionLocal() as db:
        entities_response = await db_service.get_entities(skip=0, limit=1000, db=db)
        # Extract only entity_ids for efficient filtering
        tracked_entity_ids = [entity.entity_id for entity in entities_response]
        print(f"{color_style.INFO} Tracking {(tracked_entity_ids)} entities from DB")
    
    async with websockets.connect(ws_url, ssl=True) as ws:
        # Wait for auth request
        auth_message = await ws.recv()
        print(f"{color_style.LOGGER} Auth message: {auth_message}")

        # Send the authentication token
        await ws.send(json.dumps({
            "type": "auth",
            "access_token": token
        }))

        # Wait for confirmation
        auth_ok = await ws.recv()
        print(f"{color_style.LOGGER} Auth OK: {auth_ok}")

        # Subscribe to state change events
        await ws.send(json.dumps({
            "id": 1,
            "type": "subscribe_events",
            "event_type": "state_changed"
        }))

        print(f"{color_style.INFO} Listening for state changes...")

        while True:
            msg = await ws.recv()
            event = json.loads(msg)
            
            if event.get("type") == "event":
                entity_id = event["event"]["data"]["entity_id"]
                new_state = event["event"]["data"]["new_state"]
                
                # Only process entities that are tracked in the DB
                if entity_id in tracked_entity_ids:
                    print(f"{color_style.INFO} {entity_id} changed to: {new_state['state']}")
                    
                    # Update the entity in the database using the service
                    async with AsyncSessionLocal() as db:
                        entity_update = EntityUpdate(
                            state=new_state.get("state"),
                            attributes=new_state.get("attributes", {})
                        )
                        await db_service.update_entity(
                            entity_id=entity_id,
                            entity_update=entity_update,
                            db=db
                        )
                        print(f"{color_style.LOGGER} Updated {entity_id} in database")
                    
                    # Broadcast state change to all connected WebSocket clients
                    if ws_manager:
                        await ws_manager.broadcast({
                            "type": "entity_state_changed",
                            "data": {
                                "entity_id": entity_id,
                                "state": new_state.get("state"),
                                "attributes": new_state.get("attributes", {}),
                                "timestamp": datetime.now().isoformat()
                            }
                        })
                        print(f"{color_style.LOGGER} Broadcasted state change for {entity_id} to WebSocket clients")

