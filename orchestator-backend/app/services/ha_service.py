from fastapi import APIRouter, HTTPException
import requests
import httpx
from collections import defaultdict
from app.core.config import settings
from app.utils import color_style

url = f"{settings.ha_url}"
headers = {
    "Authorization": f"Bearer {settings.ha_token}",
    "Content-Type": "application/json",
}


async def get_ha_devices():

    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(f"{url}/states", headers=headers)
            response.raise_for_status()
        except httpx.RequestError as e:
            print(f"{color_style.ERROR} Connection error: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Connection error: {str(e)}")
        except httpx.HTTPStatusError as e:
            print(f"{color_style.ERROR} HTTP error: {str(e)}")
            raise HTTPException(
                status_code=e.response.status_code,
                detail="Error fetching data from Home Assistant",
            )

    entities = response.json()
    grouped = defaultdict(list)

    for entity in entities:
        domain = entity["entity_id"].split(".")[0]
        grouped[domain].append(entity)

    # Convert to list of dicts
    result = [{"domain": domain, "entities": objs} for domain, objs in grouped.items()]
    return result


async def get_ha_device(entity_id):
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(f"{url}/states/{entity_id}", headers=headers)
            response.raise_for_status()
        except httpx.RequestError as e:
            print(f"{color_style.ERROR} Connection error: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Connection error: {str(e)}")
        except httpx.HTTPStatusError as e:
            print(f"{color_style.ERROR} HTTP error: {str(e)}")
            raise HTTPException(
                status_code=e.response.status_code,
                detail="Error fetching data from Home Assistant",
            )

    return response.json()


async def get_ha_devices_by_domain(domain: str):
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(f"{url}/states", headers=headers)
            response.raise_for_status()
        except httpx.RequestError as e:
            print(f"{color_style.ERROR} Connection error: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Connection error: {str(e)}")
        except httpx.HTTPStatusError as e:
            print(f"{color_style.ERROR} HTTP error: {str(e)}")
            raise HTTPException(
                status_code=e.response.status_code,
                detail="Error fetching data from Home Assistant",
            )

    entities = response.json()
    filtered_entities = [
        entity for entity in entities if entity["entity_id"].startswith(f"{domain}.")
    ]

    return filtered_entities


async def change_ha_entity_state(entity_id: str, new_state: str):
    payload = {"entity_id": entity_id}
    domain = entity_id.split(".")[0]
    service = new_state.lower() == "on" and "turn_on" or "turn_off"
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(
                f"{url}/services/{domain}/{service}", headers=headers, json=payload
            )
            response.raise_for_status()
        except httpx.RequestError as e:
            print(f"{color_style.ERROR} Connection error: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Connection error: {str(e)}")
        except httpx.HTTPStatusError as e:
            print(f"{color_style.ERROR} HTTP error: {str(e)}")
            raise HTTPException(
                status_code=e.response.status_code,
                detail=f"Error changing entity state in Home Assistant {e.response.text}",
            )
    return response.json()


async def get_single_ha_device(domain: str):
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(f"{url}/states", headers=headers)
            response.raise_for_status()
        except httpx.RequestError as e:
            print(f"{color_style.ERROR} Connection error: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Connection error: {str(e)}")
        except httpx.HTTPStatusError as e:
            print(f"{color_style.ERROR} HTTP error: {str(e)}")
            raise HTTPException(
                status_code=e.response.status_code,
                detail="Error fetching data from Home Assistant",
            )

    entities = response.json()
    filtered_entities = [
        entity for entity in entities if entity["entity_id"].startswith(f"{domain}.")
    ]
    return filtered_entities
