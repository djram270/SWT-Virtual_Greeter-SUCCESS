from typing import List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.repositories.entity_repository import EntityRepository
import app.services.db_service as db_service
from app.schemas.entity import (
    EntityCreate,
    EntityUpdate,
    EntityResponse
)

router = APIRouter(prefix="/entities", tags=["entities"])


@router.post("/", response_model=EntityResponse)
async def create_entity(
    entity: EntityCreate,
    db: AsyncSession = Depends(get_db)
) -> EntityResponse:
    """Create a new entity"""
    try:
        return await db_service.create_entity(entity, db)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Could not create entity: {str(e)}")


@router.get("/{entity_id}", response_model=EntityResponse)
async def get_entity(
    entity_id: str,
    db: AsyncSession = Depends(get_db)
) -> EntityResponse:
    """Get an entity by ID"""
    entity = await db_service.get_entity_by_id(entity_id, db)
    if not entity:
        raise HTTPException(status_code=404, detail=f"Entity {entity_id} not found")
    return entity


@router.get("/", response_model=List[EntityResponse])
async def get_entities(
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db)
) -> List[EntityResponse]:
    return await db_service.get_entities(skip=skip, limit=limit, db=db)


@router.put("/{entity_id}", response_model=EntityResponse)
async def update_entity(
    entity_id: str,
    entity_update: EntityUpdate,
    db: AsyncSession = Depends(get_db)
) -> EntityResponse:
    """Update an entity"""
    updated = await db_service.update_entity(entity_id, entity_update, db)
    if not updated:
        raise HTTPException(status_code=404, detail=f"Entity {entity_id} not found")
    return updated


@router.delete("/{entity_id}")
async def delete_entity(
    entity_id: str,
    db: AsyncSession = Depends(get_db)
) -> dict:
    """Delete an entity"""
    deleted = await db_service.delete_entity(entity_id, db)
    if not deleted:
        raise HTTPException(status_code=404, detail=f"Entity {entity_id} not found")
    return {"message": f"Entity {entity_id} deleted successfully"}