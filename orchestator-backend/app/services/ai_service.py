import json
import httpx
from fastapi import HTTPException
from app.core.config import settings
from app.utils import rob_context, color_style

context = rob_context.VIRTUAL_GREETER_CONTEXT

async def ask_gemini(prompt: dict, model: str = "gemini-2.5-flash"):
    
    base_url = settings.gemini_base_url.rstrip("/")
    url = f"{base_url}/{model}:generateContent?key={settings.gemini_api_key}"
    history = prompt.get("history", [])
    prompt_text = json.dumps(prompt, ensure_ascii=False)
    print(f"{color_style.LOGGER}{prompt_text}")
    
    headers = {
        "Content-Type": "application/json"
    }
    body = {
        "contents": [
            {"parts": [{"text": context}]},
            {"parts": [{"text": prompt_text}]}
        ]
    }
    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            resp = await client.post(url, headers=headers, json=body)
            resp.raise_for_status()
        except httpx.RequestError as e:
            print(f"{color_style.ERROR} Connection error: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Error de conexión con Gemini: {e.__class__.__name__} - {str(e)}")
        except httpx.HTTPStatusError as e:
            print(f"{color_style.ERROR} HTTP error: {str(e)}")
            raise HTTPException(status_code=e.response.status_code, detail=f"Error llamando Gemini: {e.response.text}")
        except Exception as e:
            print(f"{color_style.ERROR} Unexpected error: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Error inesperado: {str(e)}")

    data = resp.json()
    if "candidates" not in data or not data["candidates"]:
        print(f"{color_style.ERROR} No candidates found in Gemini response")
        raise HTTPException(status_code=500, detail="No candidates found in Gemini response")

    text = data["candidates"][0]["content"]["parts"][0]["text"]

    print(f"{color_style.LOGGER} Gemini response: {text}")
    return text
