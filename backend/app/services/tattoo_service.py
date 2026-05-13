"""
Tattoo Service - Business logic for tattoo CRUD operations.
"""

from typing import List, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from fastapi import HTTPException, status

from app.database.models import Tattoo
from app.schemas.tattoo_schema import TattooCreate


class TattooService:
    """Service class encapsulating tattoo business logic."""

    async def create_tattoo(
        self, db: AsyncSession, tattoo_data: TattooCreate
    ) -> Tattoo:
        """Create a new tattoo record in the database."""
        db_tattoo = Tattoo(
            name=tattoo_data.name,
            image_url=tattoo_data.image_url,
            file_path=tattoo_data.file_path,
            file_size=tattoo_data.file_size,
            content_type=tattoo_data.content_type,
        )
        db.add(db_tattoo)
        await db.flush()  # Get the ID without committing
        await db.refresh(db_tattoo)
        return db_tattoo

    async def get_tattoo_by_id(
        self, db: AsyncSession, tattoo_id: int
    ) -> Optional[Tattoo]:
        """Retrieve a single tattoo by its ID."""
        result = await db.execute(select(Tattoo).where(Tattoo.id == tattoo_id))
        return result.scalar_one_or_none()

    async def get_tattoo_or_404(
        self, db: AsyncSession, tattoo_id: int
    ) -> Tattoo:
        """Retrieve tattoo by ID or raise 404 HTTPException."""
        tattoo = await self.get_tattoo_by_id(db, tattoo_id)
        if not tattoo:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Tattoo with id={tattoo_id} not found",
            )
        return tattoo

    async def get_all_tattoos(
        self, db: AsyncSession, skip: int = 0, limit: int = 50
    ) -> tuple[List[Tattoo], int]:
        """
        Retrieve all tattoos with pagination.

        Returns:
            Tuple of (tattoo list, total count)
        """
        # Total count
        count_result = await db.execute(select(func.count(Tattoo.id)))
        total = count_result.scalar_one()

        # Paginated results
        result = await db.execute(
            select(Tattoo)
            .order_by(Tattoo.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        tattoos = list(result.scalars().all())

        return tattoos, total

    async def delete_tattoo(self, db: AsyncSession, tattoo_id: int) -> bool:
        """Delete a tattoo by ID. Returns True if deleted, False if not found."""
        tattoo = await self.get_tattoo_by_id(db, tattoo_id)
        if not tattoo:
            return False
        await db.delete(tattoo)
        return True


# Singleton instance
tattoo_service = TattooService()
