from datetime import datetime
from typing import Optional, Any
from sqlalchemy import Column, String, DateTime, JSON
from app.core.database import Base


class Entity(Base):
    """SQLAlchemy ORM model for an entity (Home Assistant style)."""

    __tablename__ = "entities"

    entity_id = Column(String(255), primary_key=True, index=True)
    state = Column(String(64), nullable=False)
    attributes = Column(JSON, nullable=False, default={})
    last_updated = Column(DateTime, default=datetime.utcnow, nullable=False)
    last_changed = Column(DateTime, default=datetime.utcnow, nullable=False)
    context = Column(JSON, nullable=False, default={})

    def to_dict(self) -> dict:
        return {
            "entity_id": self.entity_id,
            "state": self.state,
            "attributes": self.attributes or {},
            "last_updated": self.last_updated.isoformat() if self.last_updated else None,
            "last_changed": self.last_changed.isoformat() if self.last_changed else None,
            "context": self.context or {},
        }

    @classmethod
    def from_dict(cls, data: dict) -> "Entity":
        return cls(
            entity_id=data.get("entity_id"),
            state=data.get("state"),
            attributes=data.get("attributes") or {},
            last_updated=datetime.fromisoformat(data.get("last_updated")) if data.get("last_updated") else None,
            last_changed=datetime.fromisoformat(data.get("last_changed")) if data.get("last_changed") else None,
            context=data.get("context") or {},
        )