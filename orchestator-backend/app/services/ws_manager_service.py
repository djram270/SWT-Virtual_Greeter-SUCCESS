import base64
import json
from app.utils import color_style
from typing import Dict, Any
from datetime import datetime
from app.services import ha_service, whisper_service, ai_service
from fastapi import APIRouter, WebSocket, WebSocketDisconnect

class ConnectionManager:
    """Manages WebSocket connections and routes messages to appropriate handlers"""

    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}
        self.message_handlers = {
            "iot_control": self.handle_iot_control,
            "text_command": self.handle_text_command,
            "audio_command": self.handle_audio_command,
            "status_request": self.handle_status_request,
            "ping": self.handle_ping,
            "get_device_state": self.handle_get_device_state,
        }

    async def connect(self, websocket: WebSocket, client_id: str):
        """Register new WebSocket client connection"""
        await websocket.accept()
        self.active_connections[client_id] = websocket
        print(f"{color_style.CONNECTION} Client {client_id} connected")

    def disconnect(self, client_id: str):
        """Remove client from active connections"""
        if client_id in self.active_connections:
            del self.active_connections[client_id]
            print(f"{color_style.DISCONNECTION} Client {client_id} disconnected")

    async def send_message(self, client_id: str, message: Dict[str, Any]):
        """Send JSON message to specific client"""
        if client_id in self.active_connections:
            websocket = self.active_connections[client_id]
            await websocket.send_json(message)

    async def broadcast(self, message: Dict[str, Any], exclude_client: str = None):
        """Broadcast message to all connected clients"""
        for client_id, websocket in self.active_connections.items():
            if client_id != exclude_client:
                try:
                    await websocket.send_json(message)
                except Exception as e:
                    print(f"{color_style.ERROR} Error broadcasting to {client_id}: {str(e)}")

    async def route_message(
        self, message: Dict[str, Any], client_id: str
    ) -> Dict[str, Any]:
        """Route incoming message to appropriate handler based on message type"""
        message_type = message.get("type")

        if message_type not in self.message_handlers:
            return {
                "status": "error",
                "message": f"Unknown message type: {message_type}",
            }

        handler = self.message_handlers[message_type]
        return await handler(message.get("data", {}), client_id)

    """
        Handle audio command processing

        Pipeline: Audio (base64) -> STT -> NLP -> TTS -> Response Audio

        Args:
            data: Message data containing base64 encoded audio
            client_id: Client identifier

        Returns:
            Dict with transcription, intent, and response
    """
    async def handle_audio_command(
        self, data: Dict[str, Any], client_id: str
    ) -> Dict[str, Any]:
        
        audio_base64 = data.get("audio")

        if not audio_base64:
            return {"status": "error", "message": "Missing audio data"}

        try:
            # Validate audio size (max 5MB)
            if len(audio_base64) > 5242880:
                return {"status": "error", "message": "Audio too large (max 5MB)"}
            # Decode audio from base64
            audio_bytes = base64.b64decode(audio_base64)
            print(f"{color_style.LOGGER} Received {len(audio_bytes)} bytes from {client_id}")

            # Get audio format from data or default to wav
            audio_format = data.get("format", "wav").lower()
            if audio_format not in ["wav", "mp3"]:
                return {"status": "error", "message": f"Unsupported audio format: {audio_format}"}

            # Get transcription using Whisper STT
            print(f"{color_style.LOGGER} Processing {audio_format.upper()} audio...")
            transcription = await whisper_service.transcribe_audio(audio_bytes, audio_format=audio_format)
            print(f"{color_style.LOGGER} Transcription result: {transcription}")

            # TODO: Implement Natural Language Processing (NLP)
            #nlp_result = await nlp_service.process_command(transcription)
            # nlp_result = {
            #     "intent": "greeting",
            #     "response": "I received your audio message",
            #     "action": None,
            # }

            # Execute action if it's an IoT control command
            # if nlp_result.get("intent") == "iot_control":
            #     entity_id = nlp_result.get("entity_id")
            #     action = nlp_result.get("action")
            #     if entity_id and action:
            #         await ha_service.change_ha_entity_state(
            #             entity_id, "on" if action == "turn_on" else "off"
            #         )

            # TODO: Implement Text-to-Speech (TTS)
            # response_audio = await tts_service.synthesize(nlp_result["response"])
            # response_audio_base64 = ""

            return {
                "status": "success",
                "data": {
                    "transcription": transcription,
                    # s# "audio": response_audio_base64,  # Base64 encoded MP3
                    "timestamp": datetime.now().isoformat(),
                },
            }

        except Exception as e:
            print(f"{color_style.ERROR} Audio processing error: {str(e)}")
            return {"status": "error", "message": f"Audio processing failed: {str(e)}"}

    async def handle_iot_control(
            self, data: Dict[str, Any], client_id: str
    ) -> Dict[str, Any]:
        """
        Handle IoT device control commands

        Args:
            data: Message data with entity_id and new_state
            client_id: Client identifier

        Returns:
            Dict with success/error status
        """
        entity_id = data.get("entity_id")
        new_state = data.get("new_state")

        if not entity_id or not new_state:
            return {"status": "error", "message": "Missing entity_id or new_state"}

        try:

            result = await ha_service.change_ha_entity_state(entity_id, new_state)
            # Broadcast state change to all clients
            await self.broadcast(
                {
                    "status": "synchronizing_iot",
                    "type": "iot_state_changed",
                    "data": {
                        "entity_id": entity_id,
                        "new_state": new_state,
                        "timestamp": datetime.now().isoformat(),
                    },
                },
                #exclude_client=client_id,
            )

            print(f"[IOT] Control command: {entity_id} -> {new_state}")

            return {
                "status": "success",
                "message": f"Changed {entity_id} to {new_state}",
                "data": result,
            }

        except Exception as e:
            return {"status": "error", "message": f"IoT control error: {str(e)}"}


    async def handle_get_device_state(
        self, data: Dict[str, Any], client_id: str
    ) -> Dict[str, Any]:
        """
        Get current device state from Home Assistant

        Args:
            data: Message data with entity_id
            client_id: Client identifier

        Returns:
            Dict with device state and attributes
        """
        entity_id = data.get("entity_id")

        if not entity_id:
            return {"status": "error", "message": "Missing entity_id"}

        try:
            domain = entity_id.split(".")[0]
            devices = await ha_service.get_single_ha_device(domain)

            for device in devices:
                if device.get("entity_id") == entity_id:
                    return {
                        "status": "success",
                        "type": "device_state",
                        "data": {
                            "entity_id": entity_id,
                            "state": device.get("state", "unknown"),
                            "attributes": device.get("attributes", {}),
                        },
                    }

            return {"status": "error", "message": f"Device not found: {entity_id}"}

        except Exception as e:
            return {
                "status": "error",
                "message": f"Error getting device state: {str(e)}",
            }

    async def handle_text_command(
        self, data: Dict[str, Any], client_id: str
    ) -> Dict[str, Any]:
        """
        Handle natural language text commands

        Args:
            data: Message data with text command
            client_id: Client identifier

        Returns:
            Dict with NLP processing result
        """
        
        try:
            entity_id = data.get("entity_id")
            
            object_ = await ha_service.get_ha_device(entity_id=entity_id)
            if not object_:
                return {"status": "error", "message": f"Device not found: {entity_id}"}
            
            dialogue = data.get("text")
            if not dialogue:
                return {"status": "error", "message": "Missing text field"}
            history = data.get("history", [])
            request = {
                "object": entity_id,
                "dialogue": dialogue,
                "history": history
            }
            print(f"{color_style.LOGGER} Command received by text: {request}")
            nlp_result = await ai_service.ask_gemini(request)
            nlp_result = json.loads(nlp_result)
            instruction = nlp_result.get("instruction")
            if instruction:
                print(f"{color_style.LOGGER} Executing instruction: {instruction} on {entity_id}")
                await ha_service.change_ha_entity_state(entity_id, instruction)
            return {"status": "success", "data": nlp_result}

        except Exception as e:
            return {"status": "error", "message": f"NLP processing error: {str(e)}"}

    async def handle_status_request(
        self, data: Dict[str, Any], client_id: str
    ) -> Dict[str, Any]:
        """
        Return system and backend status

        Args:
            data: Message data (unused)
            client_id: Client identifier

        Returns:
            Dict with system status information
        """
        return {
            "status": "success",
            "data": {
                "connected_clients": len(self.active_connections),
                "home_assistant_status": "connected",
                "timestamp": datetime.now().isoformat(),
            },
        }

    async def handle_ping(self, data: Dict[str, Any], client_id: str) -> Dict[str, Any]:
        """
        Handle ping/keep-alive messages

        Args:
            data: Message data (unused)
            client_id: Client identifier

        Returns:
            Dict with pong response
        """
        return {
            "status": "success",
            "type": "pong",
            "timestamp": datetime.now().isoformat(),
        }
    