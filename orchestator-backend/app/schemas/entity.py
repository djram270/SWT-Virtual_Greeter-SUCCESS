from datetime import datetime
from typing import Optional, Dict, Any
from pydantic import BaseModel, Field


class EntityBase(BaseModel):
    """Base schema with common Entity attributes"""
    entity_id: str = Field(..., description="Unique identifier for the entity")
    state: str = Field(..., description="Current state of the entity")
    attributes: Dict[str, Any] = Field(default_factory=dict, description="Entity attributes")


class EntityCreate(EntityBase):
    """Schema for creating a new entity"""
    pass


class EntityUpdate(BaseModel):
    """Schema for updating an entity"""
    state: Optional[str] = Field(None, description="New state of the entity")
    attributes: Optional[Dict[str, Any]] = Field(None, description="Updated entity attributes")


class EntityInDB(EntityBase):
    """Schema for entity as stored in database"""
    last_updated: datetime
    last_changed: datetime
    context: Dict[str, Any] = Field(default_factory=dict)

    class Config:
        from_attributes = True


class EntityResponse(EntityInDB):
    """Schema for entity responses"""
    pass