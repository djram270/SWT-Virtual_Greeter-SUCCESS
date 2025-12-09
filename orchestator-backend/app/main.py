import asyncio
from fastapi import FastAPI
from app.core.database import init_db
from fastapi.middleware.cors import CORSMiddleware
from app.api.routes import system, ha, ws_bridge, ai, entities
from app.utils import color_style
from app import listen_homeassistant
import app as app_module

app = FastAPI(
    title="Virtual Greeter Backend",
    description="Backend API for Smart Room Virtual Greeter",
    version="1.0.0",
)

# Include API routers
app.include_router(system.router, prefix="/system", tags=["System"])
app.include_router(ha.router, prefix="/ha", tags=["Home Assistant"])
app.include_router(ws_bridge.router, prefix="/ws", tags=["WebSocket"])
app.include_router(ai.router, prefix="/ai", tags=["AI"])
app.include_router(entities.router, prefix="/api", tags=["Entities"])

@app.on_event("startup")
async def startup_event():
    """Start the Home Assistant WebSocket listener when the app starts"""
    # Pass the WebSocket manager to the listen_homeassistant function
    app_module.ws_manager = ws_bridge.manager
    asyncio.create_task(listen_homeassistant())


@app.on_event("startup")
async def on_startup():
    try:
        await init_db()
    except Exception as e:
        print(f"{color_style.WARNING} init_db failed: {e}")

# CORS middleware to allow requests from Godot
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify the origin, in dev allow all
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def root():
    return {"message": "Orchestator Backend is running"}

