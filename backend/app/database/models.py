"""
SQLAlchemy ORM Models for InkVision AI database.
Includes Tattoos, TryOnResults, and Users (future-ready) tables.
"""

from datetime import datetime, timezone
from sqlalchemy import (
    Column,
    Integer,
    String,
    Float,
    Boolean,
    DateTime,
    ForeignKey,
    Text,
)
from sqlalchemy.orm import relationship
from app.database.session import Base


def utcnow():
    """Return current UTC datetime."""
    return datetime.now(timezone.utc)


class User(Base):
    """
    User model - future-ready structure for authentication.
    Not actively used in prototype but schema is defined.
    """
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    email = Column(String(255), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=True)  # nullable for social login
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)
    updated_at = Column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)

    # Relationships
    tattoos = relationship("Tattoo", back_populates="owner", lazy="selectin")
    tryon_results = relationship("TryOnResult", back_populates="user", lazy="selectin")

    def __repr__(self):
        return f"<User id={self.id} email={self.email}>"


class Tattoo(Base):
    """
    Tattoo model - stores uploaded tattoo image metadata.
    The actual image file is stored in the uploads/tattoos directory.
    """
    __tablename__ = "tattoos"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    image_url = Column(String(512), nullable=False)   # Served URL path
    file_path = Column(String(512), nullable=False)   # Actual file system path
    file_size = Column(Integer, nullable=True)        # File size in bytes
    content_type = Column(String(100), nullable=True) # MIME type
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)

    # Optional owner relationship (future auth)
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    owner = relationship("User", back_populates="tattoos")

    # Try-on results that used this tattoo
    tryon_results = relationship("TryOnResult", back_populates="tattoo", lazy="selectin")

    def __repr__(self):
        return f"<Tattoo id={self.id} name={self.name}>"


class TryOnResult(Base):
    """
    TryOn Result model - stores the final captured try-on session data.
    Includes transform parameters for reproducibility.
    """
    __tablename__ = "tryon_results"

    id = Column(Integer, primary_key=True, index=True)
    tattoo_id = Column(Integer, ForeignKey("tattoos.id"), nullable=False)
    result_image_url = Column(String(512), nullable=False)  # Served URL
    result_file_path = Column(String(512), nullable=False)  # File system path

    # Tattoo transform parameters at capture time
    position_x = Column(Float, default=0.0, nullable=False)
    position_y = Column(Float, default=0.0, nullable=False)
    scale = Column(Float, default=1.0, nullable=False)
    rotation = Column(Float, default=0.0, nullable=False)  # Degrees
    opacity = Column(Float, default=0.8, nullable=False)   # 0.0 - 1.0

    # Session notes
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)

    # Relationships
    tattoo = relationship("Tattoo", back_populates="tryon_results")
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    user = relationship("User", back_populates="tryon_results")

    def __repr__(self):
        return f"<TryOnResult id={self.id} tattoo_id={self.tattoo_id}>"
