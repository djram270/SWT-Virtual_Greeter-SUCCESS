from fastapi import APIRouter
from pydantic import BaseModel
from app.services.ai_service import ask_gemini
from app.utils import color_style
router = APIRouter()

class PromptRequest(BaseModel):
    prompt: str

@router.post("/generate")
async def generate(prompt_req: PromptRequest):
    print(f"{color_style.ORANGE}[LOGGER]{color_style.RESET} Received prompt:", prompt_req.prompt)
    result = await ask_gemini(prompt_req.prompt)
    return {"response": result}

# @router.get("/models")
# async def list_models():
#     result = await list_gemini_models()
#     return result