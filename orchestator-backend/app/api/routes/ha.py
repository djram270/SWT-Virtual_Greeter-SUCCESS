from fastapi import APIRouter
from app.services import ha_service

router = APIRouter()


@router.get("/get-devices")
async def get_devices():
    return await ha_service.get_ha_devices()


@router.get("/get-device/{entity_id}")
async def get_device(entity_id: str):
    return await ha_service.get_ha_device(entity_id)


@router.get("/get-devices/{domain}")
async def get_devices_by_domain(domain: str):
    return await ha_service.get_ha_devices_by_domain(domain)


@router.get("/get-single-device/{domain}")
async def get_single_device(domain: str):
    return await ha_service.get_single_ha_device(domain)


@router.post("/change-state/{entity_id}/{new_state}")
async def change_state(entity_id: str, new_state: str):
    await ha_service.change_ha_entity_state(entity_id, new_state)
