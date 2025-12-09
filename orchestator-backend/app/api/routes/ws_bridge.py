"""
Unified WebSocket Bridge

Handles all Godot-Backend communication via WebSocket with support for:
- Audio command processing (STT, NLP, TTS)
- IoT device control
- Text-based natural language commands
- Status requests and connection management
"""
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from app.services import ha_service
from app.services import whisper_service
from app.services import ai_service
from typing import Dict, Any
import json
import base64
import asyncio
from datetime import datetime
from app.services.ws_manager_service import ConnectionManager
from app.utils import color_style
router = APIRouter(tags=["WebSocket"])

# Global connection manager instance
manager = ConnectionManager()

@router.websocket("/unified")
async def unified_websocket(websocket: WebSocket):
    """
    Unified WebSocket endpoint for all Godot-Backend communication

    Handles:
    - Audio commands (STT, NLP, TTS)
    - IoT device control
    - Text-based natural language commands
    - Device state queries
    - Connection keep-alive
    """
    client_id = f"client_{id(websocket)}"
    await manager.connect(websocket, client_id)

    try:
        while True:
            data = await websocket.receive_text()
            message = json.loads(data)
            message_type = message.get("type", "unknown")
            print(f"{color_style.LOGGER} From {client_id}: {message_type}")

            # Route message to appropriate handler
            response = await manager.route_message(message, client_id)

            # Send response back to client
            await websocket.send_json(response)

    except WebSocketDisconnect:
        manager.disconnect(client_id)
        print(f"{color_style.DISCONNECTION} Client {client_id} disconnected gracefully")
    except Exception as e:
        print(f"{color_style.ERROR} Client {client_id}: {str(e)}")
        manager.disconnect(client_id)

@router.websocket("/topic")
async def ws_write(websocket: WebSocket):
    """
    This route will be used to communicate the backend and Godot via WebSocket
    """
    client_id = f"client_{id(websocket)}"
    await manager.connect(websocket, client_id)

    try:
        while True:
            data = await websocket.receive_text()
            message = json.loads(data)
            message_type = message.get("type", "unknown")
            print(f"{color_style.LOGGER} From {client_id}: {message_type}")

            # Route message to appropriate handler
            response = await manager.route_message(message, client_id)

            # Send response back to client
            await websocket.send_json(response)

    except WebSocketDisconnect:
        manager.disconnect(client_id)
        print(f"{color_style.DISCONNECTION} Client {client_id} disconnected gracefully")
    except Exception as e:
        print(f"{color_style.ERROR} Client {client_id}: {str(e)}")
        manager.disconnect(client_id)
