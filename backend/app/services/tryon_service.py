"""
TryOn Service - Business logic for try-on session management.
"""

from typing import List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from fastapi import HTTPException, status

from app.database.models import TryOnResult
from app.schemas.tryon_schema import SaveResultRequest


class TryOnService:
    """Service class for try-on result management."""

    async def save_result(
        self,
        db: AsyncSession,
        request: SaveResultRequest,
        result_image_url: str,
        result_file_path: str,
    ) -> TryOnResult:
        """Save a try-on result record to the database."""
        db_result = TryOnResult(
            tattoo_id=request.tattoo_id,
            result_image_url=result_image_url,
            result_file_path=result_file_path,
            position_x=request.position_x,
            position_y=request.position_y,
            scale=request.scale,
            rotation=request.rotation,
            opacity=request.opacity,
            notes=request.notes,
        )
        db.add(db_result)
        await db.flush()
        await db.refresh(db_result)
        return db_result

    async def get_history(
        self, db: AsyncSession, skip: int = 0, limit: int = 50
    ) -> tuple[List[TryOnResult], int]:
        """
        Retrieve try-on history with pagination.

        Returns:
            Tuple of (results list, total count)
        """
        count_result = await db.execute(select(func.count(TryOnResult.id)))
        total = count_result.scalar_one()

        result = await db.execute(
            select(TryOnResult)
            .order_by(TryOnResult.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        results = list(result.scalars().all())

        return results, total

    async def get_result_by_id(
        self, db: AsyncSession, result_id: int
    ) -> TryOnResult:
        """Get a single try-on result by ID."""
        result = await db.execute(
            select(TryOnResult).where(TryOnResult.id == result_id)
        )
        record = result.scalar_one_or_none()
        if not record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"TryOn result with id={result_id} not found",
            )
        return record


# Singleton instance
tryon_service = TryOnService()
