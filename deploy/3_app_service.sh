#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Step 3 — Deploy the FastAPI + ADK app on Cloud Run
#
# This deploys your vision agent web app. It points at the vLLM service
# deployed in step 2. No GPU needed — this is just Python + FastAPI.
#
# Run AFTER deploy/2_vllm_service.sh has finished.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Config — edit these ───────────────────────────────────────────────────────
PROJECT_ID="valued-mediator-461216-k7"
REGION="us-east4"
SERVICE_NAME="gemma4-vision-app"

# Filled in automatically from step 2 output — update if URL differs
VLLM_URL="https://gemma4-vllm-xxxxxxxxxx-uc.a.run.app"   # ← paste URL from step 2
MODEL_NAME="gs://valued-mediator-461216-k7-gemma4-models/models/gemma-4-E2B-it"
# ─────────────────────────────────────────────────────────────────────────────

echo "==> Setting project: ${PROJECT_ID}"
gcloud config set project "${PROJECT_ID}"

echo "==> Enabling required APIs"
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  --quiet

echo "==> Building and deploying app: ${SERVICE_NAME}"
echo "    vLLM backend : ${VLLM_URL}"
echo "    Model name   : ${MODEL_NAME}"
echo ""

# Deploy from source — Cloud Build builds the Dockerfile automatically
gcloud run deploy "${SERVICE_NAME}" \
  --source="$(dirname "$(pwd)")" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --allow-unauthenticated \
  --cpu=2 \
  --memory=2Gi \
  --min-instances=0 \
  --max-instances=10 \
  --concurrency=80 \
  --timeout=300 \
  --set-env-vars="OPENAI_API_BASE=${VLLM_URL}/v1,OPENAI_API_KEY=dummy,MODEL_NAME=${MODEL_NAME}"

echo ""
echo "==> Getting app URL..."
APP_URL=$(gcloud run services describe "${SERVICE_NAME}" \
  --region="${REGION}" \
  --format="value(status.url)")

echo ""
echo "✓ App deployed!"
echo ""
echo "  App URL  : ${APP_URL}"
echo "  Health   : ${APP_URL}/health"
echo ""
echo "Open ${APP_URL} in your browser to demo the full Cloud Run stack."
