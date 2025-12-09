from datetime import datetime
from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.entity import Entity
from app.core.database import AsyncSessionLocal


class EntityRepository:
    """Repository for Entity CRUD operations"""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def create(self, entity_id: str, state: str, attributes: Optional[dict] = None) -> Entity:
        """Create a new entity"""
        entity = Entity(
            entity_id=entity_id,
            state=state,
            attributes=attributes or {}
        )
        self.session.add(entity)
        await self.session.commit()
        await self.session.refresh(entity)
        return entity

    async def get_by_id(self, entity_id: str) -> Optional[Entity]:
        """Get an entity by its ID"""
        result = await self.session.execute(
            select(Entity).where(Entity.entity_id == entity_id)
        )
        return result.scalar_one_or_none()

    async def get_all(self, skip: int = 0, limit: int = 100) -> List[Entity]:
        """Get all entities with pagination"""
        result = await self.session.execute(
            select(Entity).offset(skip).limit(limit)
        )
        return result.scalars().all()

    async def update(
        self,
        entity_id: str,
        state: Optional[str] = None,
        attributes: Optional[dict] = None
    ) -> Optional[Entity]:
        """Update an entity"""
        entity = await self.get_by_id(entity_id)
        if not entity:
            return None

        if state is not None:
            entity.state = state
            entity.last_changed = datetime.now()

        if attributes is not None:
            entity.attributes.update(attributes)

        entity.last_updated = datetime.now()
        await self.session.commit()
        await self.session.refresh(entity)
        return entity

    async def delete(self, entity_id: str) -> bool:
        """Delete an entity"""
        entity = await self.get_by_id(entity_id)
        if not entity:
            return False

        await self.session.delete(entity)
        await self.session.commit()
        return True