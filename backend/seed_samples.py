import os
import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
from dotenv import load_dotenv

load_dotenv()

DB_URL = os.getenv("DATABASE_URL", "postgresql+asyncpg://postgres:password@localhost:5432/inkvision_db")

async def seed_tattoos():
    engine = create_async_engine(DB_URL)
    
    tattoos = [
        {"name": "Geometric Wolf", "image_url": "/uploads/wolf.png"},
        {"name": "Minimalist Floral", "image_url": "/uploads/floral.png"},
        {"name": "Abstract Face", "image_url": "/uploads/abstract.png"},
    ]

    async with engine.begin() as conn:
        for t in tattoos:
            result = await conn.execute(text("SELECT id FROM tattoos WHERE name = :name"), {"name": t["name"]})
            if not result.fetchone():
                await conn.execute(
                    text("INSERT INTO tattoos (name, image_url, created_at) VALUES (:name, :image_url, now())"),
                    t
                )
                print(f"Added {t['name']}")
            else:
                print(f"Skipping {t['name']}, already exists")
    
    await engine.dispose()

if __name__ == "__main__":
    asyncio.run(seed_tattoos())
