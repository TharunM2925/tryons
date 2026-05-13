"""
Tattoo Router - API endpoints for tattoo upload and management.
"""

from fastapi import APIRouter, Depends, UploadFile, File, Form, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.session import get_db
from app.schemas.tattoo_schema import (
    TattooResponse,
    TattooUploadResponse,
    TattooListResponse,
    TattooCreate,
)
from app.services.tattoo_service import tattoo_service
from app.utils.file_utils import validate_and_save_upload

router = APIRouter()


@router.post("/upload", response_model=TattooUploadResponse, status_code=201)
async def upload_tattoo(
    file: UploadFile = File(..., description="Tattoo image file (PNG/JPG/WEBP)"),
    name: str = Form(..., description="Tattoo design name"),
    db: AsyncSession = Depends(get_db),
):
    """
    Upload a new tattoo image.

    - **file**: Image file (PNG recommended for transparency support)
    - **name**: Display name for the tattoo design

    Returns the tattoo ID and image URL for use in the try-on screen.
    """
    # Validate and save uploaded file
    file_path, image_url, file_size = await validate_and_save_upload(file, "tattoos")

    # Create database record
    tattoo_data = TattooCreate(
        name=name,
        image_url=image_url,
        file_path=file_path,
        file_size=file_size,
        content_type=file.content_type,
    )
    tattoo = await tattoo_service.create_tattoo(db, tattoo_data)

    return TattooUploadResponse(
        tattoo_id=tattoo.id,
        name=tattoo.name,
        image_url=tattoo.image_url,
    )


@router.get("", response_model=TattooListResponse)
async def list_tattoos(
    skip: int = Query(default=0, ge=0, description="Number of records to skip"),
    limit: int = Query(default=50, ge=1, le=100, description="Max records to return"),
    db: AsyncSession = Depends(get_db),
):
    """
    Get a paginated list of all uploaded tattoos.
    """
    tattoos, total = await tattoo_service.get_all_tattoos(db, skip=skip, limit=limit)
    return TattooListResponse(
        total=total,
        tattoos=[TattooResponse.model_validate(t) for t in tattoos],
    )


@router.get("/{tattoo_id}", response_model=TattooResponse)
async def get_tattoo(
    tattoo_id: int,
    db: AsyncSession = Depends(get_db),
):
    """
    Get details for a specific tattoo by ID.
    """
    tattoo = await tattoo_service.get_tattoo_or_404(db, tattoo_id)
    return TattooResponse.model_validate(tattoo)


@router.delete("/{tattoo_id}", status_code=204)
async def delete_tattoo(
    tattoo_id: int,
    db: AsyncSession = Depends(get_db),
):
    """
    Delete a tattoo by ID.
    """
    await tattoo_service.get_tattoo_or_404(db, tattoo_id)
    await tattoo_service.delete_tattoo(db, tattoo_id)
