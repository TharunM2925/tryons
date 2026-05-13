"""
Pydantic schemas for TryOn API request/response validation.
"""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field, ConfigDict


class ProcessFrameRequest(BaseModel):
    """Request schema for processing a camera frame."""
    tattoo_id: int = Field(..., description="ID of the tattoo to overlay")
    frame_base64: str = Field(..., description="Base64 encoded camera frame image")


class BoundingBox(BaseModel):
    """Bounding box coordinates for detected skin region."""
    x: int = Field(..., description="Top-left x coordinate")
    y: int = Field(..., description="Top-left y coordinate")
    width: int = Field(..., description="Width of bounding box")
    height: int = Field(..., description="Height of bounding box")


class ProcessFrameResponse(BaseModel):
    """Response from frame processing with skin detection result."""
    skin_detected: bool
    confidence: float = Field(default=0.0, ge=0.0, le=1.0)
    bounding_box: Optional[BoundingBox] = None
    skin_area_percentage: float = Field(default=0.0, description="% of frame covered by skin")
    message: str = ""


class SaveResultRequest(BaseModel):
    """Request schema for saving a try-on result."""
    tattoo_id: int
    result_image_base64: str = Field(..., description="Base64 encoded captured image")
    position_x: float = Field(default=0.0)
    position_y: float = Field(default=0.0)
    scale: float = Field(default=1.0, gt=0)
    rotation: float = Field(default=0.0)
    opacity: float = Field(default=0.8, ge=0.0, le=1.0)
    notes: Optional[str] = None


class TryOnResultResponse(BaseModel):
    """Response schema for a saved try-on result."""
    model_config = ConfigDict(from_attributes=True)

    id: int
    tattoo_id: int
    result_image_url: str
    position_x: float
    position_y: float
    scale: float
    rotation: float
    opacity: float
    notes: Optional[str]
    created_at: datetime


class TryOnHistoryResponse(BaseModel):
    """Paginated history of try-on results."""
    total: int
    results: list[TryOnResultResponse]
