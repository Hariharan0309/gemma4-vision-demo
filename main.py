import json
import os
import uuid

from dotenv import load_dotenv
from fastapi import FastAPI, File, Form, UploadFile
from fastapi.responses import HTMLResponse, StreamingResponse
from google.adk.runners import Runner
from google.adk.sessions import InMemorySessionService
from google.genai import types

from agent import root_agent

load_dotenv()

APP_NAME = "gemma4_vision_demo"

session_service = InMemorySessionService()
runner = Runner(
    agent=root_agent,
    app_name=APP_NAME,
    session_service=session_service,
)

app = FastAPI(title="Gemma 4 Vision Agent")


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
    mime_type = image.content_type or "image/jpeg"

    session_id = str(uuid.uuid4())
    user_id = "demo_user"

    await session_service.create_session(
        app_name=APP_NAME,
        user_id=user_id,
        session_id=session_id,
    )

    # Build a multimodal message: image + question text
    message = types.Content(
        role="user",
        parts=[
            types.Part(
                inline_data=types.Blob(mime_type=mime_type, data=image_bytes)
            ),
            types.Part(text=question),
        ],
    )

    async def stream_events():
        async for event in runner.run_async(
            user_id=user_id,
            session_id=session_id,
            new_message=message,
        ):
            if not event.content or not event.content.parts:
                continue
            for part in event.content.parts:
                if part.text:
                    payload = json.dumps({
                        "agent": event.author,
                        "text": part.text,
                    })
                    yield f"data: {payload}\n\n"
        yield "data: [DONE]\n\n"

    return StreamingResponse(stream_events(), media_type="text/event-stream")


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "model_url": os.getenv("OPENAI_API_BASE", "http://localhost:11434/v1"),
        "model_name": os.getenv("MODEL_NAME", "gemma4:e2b"),
        "agents": [a.name for a in root_agent.sub_agents],
    }
