"""
Pydantic schemas for Tattoo API request/response validation.
"""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field, ConfigDict


class TattooBase(BaseModel):
    """Base tattoo schema with common fields."""
    name: str = Field(..., min_length=1, max_length=255, description="Tattoo design name")


class TattooCreate(TattooBase):
    """Schema for tattoo creation (internal use after upload)."""
    image_url: str
    file_path: str
    file_size: Optional[int] = None
    content_type: Optional[str] = None


class TattooResponse(TattooBase):
    """Schema for tattoo API responses."""
    model_config = ConfigDict(from_attributes=True)

    id: int
    image_url: str
    file_size: Optional[int] = None
    content_type: Optional[str] = None
    created_at: datetime


class TattooUploadResponse(BaseModel):
    """Response after uploading a tattoo image."""
    tattoo_id: int
    name: str
    image_url: str
    message: str = "Tattoo uploaded successfully"


class TattooListResponse(BaseModel):
    """Paginated list of tattoos."""
    total: int
    tattoos: list[TattooResponse]
