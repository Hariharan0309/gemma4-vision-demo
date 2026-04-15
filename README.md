# Gemma 4 Vision Agent

A multimodal Q&A app powered by **Gemma 4** and **Google ADK**. Drop a screenshot — a two-agent pipeline visually analyzes it, explains what it shows, and suggests next steps.

Built with FastAPI + Google ADK + Ollama. No API keys. No cloud bill. Runs entirely on your machine.

![Pipeline: Vision Analyzer → Explainer & Suggester]

---

## How it works

```
Your image + question
        ↓
  VisionAnalyzer        — extracts image type, visible elements, key data points
        ↓
  ExplainerSuggester    — explains in plain English + suggests next steps
```

Both agents run on **Gemma 4 E2B** served locally via Ollama.

---

## Requirements

- Linux or macOS
- Python 3.10+
- ~8 GB RAM (model loads into CPU/GPU shared memory)
- ~8 GB free disk space (for the model)

---

## Step 1 — Install Ollama

Ollama runs the Gemma 4 model locally and exposes an OpenAI-compatible API on port `11434`.

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

Verify the install:

```bash
ollama --version
```

Check that the Ollama service is running:

```bash
systemctl status ollama
```

If it is not running, start it:

```bash
ollama serve
```

---

## Step 2 — Download the Gemma 4 E2B model

```bash
ollama pull gemma4:e2b
```

This downloads ~7.2 GB. It only needs to be done once.

Verify the model was downloaded:

```bash
ollama list
```

You should see `gemma4:e2b` in the list.

Do a quick smoke test to confirm it works:

```bash
ollama run gemma4:e2b "describe yourself in one sentence"
```

---

## Step 3 — Clone the repo

```bash
git clone https://github.com/Hariharan0309/gemma4-vision-demo.git
cd gemma4-vision-demo
```

---

## Step 4 — Install Python dependencies

It is recommended to use a virtual environment:

```bash
python3 -m venv .venv
source .venv/bin/activate
```

Install dependencies:

```bash
pip install -r requirements.txt
```

---

## Step 5 — Configure environment

The `.env` file is already set up for local Ollama use. No changes needed:

```bash
cat .env
```

```
OPENAI_API_BASE=http://localhost:11434/v1
OPENAI_API_KEY=ollama
MODEL_NAME=gemma4:e2b
```

---

## Step 6 — Run the app

```bash
uvicorn main:app --reload
```

Open your browser at:

```
http://localhost:8000
```

---

## Using the app

1. Click **"Click to upload"** or drag and drop any image (PNG, JPG, WEBP)
2. Type a question in the text box — or leave it blank for a full analysis
3. Click **Analyze** (or press `Ctrl+Enter`)
4. Watch both agents work in real time:
   - **Vision Analyzer** — identifies what is in the image
   - **Explainer & Suggester** — explains it and gives next steps

### Example prompts to try

| Image | Question |
|-------|----------|
| Architecture diagram | `Explain this system to a beginner` |
| Python error traceback | `What is wrong and how do I fix it?` |
| GCP billing dashboard | `Summarize what I am spending on` |
| Any UI screenshot | `What does this screen do?` |

---

## Project structure

```
gemma4-vision-demo/
├── agent/
│   ├── __init__.py
│   └── agent.py          # ADK multi-agent pipeline definition
├── deploy/
│   ├── 1_model_to_gcs.sh # Upload model to GCS (Cloud Run only)
│   ├── 2_vllm_service.sh # Deploy vLLM backend on Cloud Run
│   └── 3_app_service.sh  # Deploy this app on Cloud Run
├── main.py               # FastAPI app + ADK Runner
├── index.html            # Frontend (single file, no framework)
├── Dockerfile            # For Cloud Run deployment
├── requirements.txt
└── .env                  # Local config
```

---

## API endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Serves the web UI |
| `/ask` | POST | Accepts `image` + `question`, streams agent output |
| `/health` | GET | Shows current model URL and name |

---

## Troubleshooting

**Ollama is not running**
```bash
ollama serve
```

**Model not found error**
```bash
ollama pull gemma4:e2b
```

**Check what is currently loaded in memory**
```bash
ollama ps
```

**App cannot connect to Ollama**

Make sure Ollama is running and the model API is reachable:
```bash
curl http://localhost:11434/v1/models
```

You should see `gemma4:e2b` in the response.

**Responses are very slow**

The E2B model runs partially on CPU if you have less than 8 GB VRAM. Expect 3–5 tokens/second on CPU. This is normal — the response will stream in gradually.

---

## Cloud Run deployment

Scripts for deploying to Google Cloud Run with an NVIDIA L4 GPU are in the `deploy/` folder. See the scripts for step-by-step instructions.

---

## License

Apache 2.0 — free for personal and commercial use.
