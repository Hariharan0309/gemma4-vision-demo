import base64
import json
import os

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, File, Form, UploadFile
from fastapi.responses import HTMLResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles

load_dotenv()

MODEL_URL = os.getenv("MODEL_URL", "http://localhost:11434/v1")
MODEL_NAME = os.getenv("MODEL_NAME", "gemma4:e2b")

app = FastAPI(title="Gemma 4 Vision Demo")


@app.get("/", response_class=HTMLResponse)
async def root():
    with open("index.html") as f:
        return f.read()


@app.post("/ask")
async def ask(
    question: str = Form(...),
    image: UploadFile = File(...),
):
    image_bytes = await image.read()
    image_b64 = base64.b64encode(image_bytes).decode()
    mime_type = image.content_type or "image/jpeg"

    payload = {
        "model": MODEL_NAME,
        "stream": True,
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:{mime_type};base64,{image_b64}"},
                    },
                    {"type": "text", "text": question},
                ],
            }
        ],
    }

    async def stream_tokens():
        async with httpx.AsyncClient(timeout=120) as client:
            async with client.stream(
                "POST",
                f"{MODEL_URL}/chat/completions",
                json=payload,
                headers={"Content-Type": "application/json"},
            ) as resp:
                resp.raise_for_status()
                async for line in resp.aiter_lines():
                    if not line.startswith("data:"):
                        continue
                    data = line[len("data:"):].strip()
                    if data == "[DONE]":
                        break
                    try:
                        chunk = json.loads(data)
                        token = chunk["choices"][0]["delta"].get("content", "")
                        if token:
                            yield token
                    except (json.JSONDecodeError, KeyError, IndexError):
                        continue

    return StreamingResponse(stream_tokens(), media_type="text/plain")


@app.get("/health")
async def health():
    return {"status": "ok", "model_url": MODEL_URL, "model_name": MODEL_NAME}
