from typing import List, Optional
from fastapi import Depends
from app.core.database import engine
from sqlalchemy import text
from app.core.database import get_db
from sqlalchemy.ext.asyncio import AsyncSession
from app.repositories.entity_repository import EntityRepository
from app.schemas.entity import (
    EntityCreate,
    EntityUpdate,
    EntityResponse,
    EntityInDB,
)

async def test_connection():
    async with engine.begin() as conn:
        result = await conn.execute(text("SELECT 1"))
        return result.scalar()


async def get_entities(
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db),
) -> List[EntityResponse]:
    """Get all entities with pagination"""
    repo = EntityRepository(db)
    entities = await repo.get_all(skip=skip, limit=limit)
    return [EntityResponse.model_validate(entity) for entity in entities]


async def create_entity(
    entity_in: EntityCreate,
    db: AsyncSession,
) -> EntityResponse:
    repo = EntityRepository(db)
    entity = await repo.create(
        entity_id=entity_in.entity_id,
        state=entity_in.state,
        attributes=entity_in.attributes,
    )
    return EntityResponse.model_validate(entity)


async def get_entity_by_id(entity_id: str, db: AsyncSession) -> Optional[EntityResponse]:
    repo = EntityRepository(db)
    entity = await repo.get_by_id(entity_id)
    if not entity:
        return None
    return EntityResponse.model_validate(entity)


async def update_entity(
    entity_id: str,
    entity_update: EntityUpdate,
    db: AsyncSession,
) -> Optional[EntityResponse]:
    repo = EntityRepository(db)
    updated = await repo.update(
        entity_id=entity_id,
        state=entity_update.state,
        attributes=entity_update.attributes,
    )
    if not updated:
        return None
    return EntityResponse.model_validate(updated)


async def delete_entity(entity_id: str, db: AsyncSession) -> bool:
    repo = EntityRepository(db)
    return await repo.delete(entity_id)