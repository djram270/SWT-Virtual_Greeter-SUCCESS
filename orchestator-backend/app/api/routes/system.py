from fastapi import APIRouter
from app.services import db_service

router = APIRouter()

@router.get("/db-check")
async def db_check():
    result = await db_service.test_connection()
    return {"ok": bool(result)}
