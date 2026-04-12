FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py index.html ./

# MODEL_URL and MODEL_NAME are injected at runtime via Cloud Run env vars
ENV MODEL_URL=http://localhost:11434/v1
ENV MODEL_NAME=gemma4:e2b

EXPOSE 8080

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
