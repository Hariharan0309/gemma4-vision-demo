FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py index.html ./
COPY agent/ ./agent/

# Defaults for local use — overridden by Cloud Run env vars at deploy time
ENV OPENAI_API_BASE=http://localhost:11434/v1
ENV OPENAI_API_KEY=ollama
ENV MODEL_NAME=gemma4:e2b

EXPOSE 8080

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
