"""
TryOn Router - API endpoints for skin detection and result saving.
"""

import base64
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.session import get_db
from app.schemas.tryon_schema import (
    ProcessFrameRequest,
    ProcessFrameResponse,
    SaveResultRequest,
    TryOnResultResponse,
    TryOnHistoryResponse,
    BoundingBox,
)
from app.services.tryon_service import tryon_service
from app.services.vision_service import vision_service
from app.services.tattoo_service import tattoo_service
from app.utils.file_utils import save_base64_image

router = APIRouter()


@router.post("/process-frame", response_model=ProcessFrameResponse)
async def process_frame(
    request: ProcessFrameRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Process a camera frame for skin detection.

    Accepts a base64-encoded camera frame and returns:
    - Whether skin is detected
    - Confidence score
    - Bounding box of the largest skin region

    The Flutter client can use this bounding box to position the tattoo overlay.
    For real-time performance, the Flutter client handles rendering; this
    endpoint provides the detection data.
    """
    # Verify tattoo exists
    await tattoo_service.get_tattoo_or_404(db, request.tattoo_id)

    # Decode base64 frame
    try:
        # Strip data URL prefix if present
        frame_b64 = request.frame_base64
        if "," in frame_b64:
            frame_b64 = frame_b64.split(",", 1)[1]
        image_bytes = base64.b64decode(frame_b64)
    except Exception:
        return ProcessFrameResponse(
            skin_detected=False,
            confidence=0.0,
            message="Invalid base64 image data",
        )

    # Run skin detection
    result = vision_service.detect_skin(image_bytes)

    # Build response
    bbox = None
    if result.get("bounding_box"):
        b = result["bounding_box"]
        bbox = BoundingBox(
            x=b["x"], y=b["y"], width=b["width"], height=b["height"]
        )

    return ProcessFrameResponse(
        skin_detected=result["skin_detected"],
        confidence=result["confidence"],
        bounding_box=bbox,
        skin_area_percentage=result["skin_area_percentage"],
        message=result["message"],
    )


@router.post("/save-result", response_model=TryOnResultResponse, status_code=201)
async def save_result(
    request: SaveResultRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Save a completed try-on result image and its metadata.

    Accepts a base64 encoded final captured image and the tattoo transform
    parameters (position, scale, rotation, opacity) for record keeping.
    """
    # Verify tattoo exists
    await tattoo_service.get_tattoo_or_404(db, request.tattoo_id)

    # Save result image
    file_path, image_url = await save_base64_image(
        request.result_image_base64, "results"
    )

    # Save to database
    db_result = await tryon_service.save_result(
        db=db,
        request=request,
        result_image_url=image_url,
        result_file_path=file_path,
    )

    return TryOnResultResponse.model_validate(db_result)


@router.get("/history", response_model=TryOnHistoryResponse)
async def get_history(
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=50, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    """
    Get the history of all saved try-on results.
    """
    results, total = await tryon_service.get_history(db, skip=skip, limit=limit)
    return TryOnHistoryResponse(
        total=total,
        results=[TryOnResultResponse.model_validate(r) for r in results],
    )


@router.get("/history/{result_id}", response_model=TryOnResultResponse)
async def get_result(
    result_id: int,
    db: AsyncSession = Depends(get_db),
):
    """
    Get a specific try-on result by ID.
    """
    result = await tryon_service.get_result_by_id(db, result_id)
    return TryOnResultResponse.model_validate(result)
