#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Step 2 — Deploy Gemma 4 vLLM backend on Cloud Run
#
# This deploys the model-serving layer using Google's prebuilt vLLM image.
# Your FastAPI app will point at this service's URL.
#
# Run AFTER deploy/1_model_to_gcs.sh has finished.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Config — edit these ───────────────────────────────────────────────────────
PROJECT_ID="valued-mediator-461216-k7"
REGION="us-east4"
SERVICE_NAME="gemma4-vllm"

GCS_MODEL_PATH="gs://valued-mediator-461216-k7-gemma4-models/models/gemma-4-E2B-it"

GPU_TYPE="nvidia-l4"     # 24 GB VRAM — fits E2B comfortably

# E2B is small — can handle 32 concurrent requests on an L4
CONCURRENCY=32
MAX_NUM_SEQS=32
# ─────────────────────────────────────────────────────────────────────────────

VLLM_IMAGE="us-docker.pkg.dev/vertex-ai/vertex-vision-model-garden-dockers/pytorch-vllm-serve:gemma4"

echo "==> Setting project: ${PROJECT_ID}"
gcloud config set project "${PROJECT_ID}"

echo "==> Enabling required APIs"
gcloud services enable run.googleapis.com \
  artifactregistry.googleapis.com \
  --quiet

echo "==> Deploying vLLM service: ${SERVICE_NAME}"
echo "    GPU: ${GPU_TYPE}"
echo "    Model: ${GCS_MODEL_PATH}"
echo "    (First deploy takes ~5 minutes — it's pulling the image)"

gcloud beta run deploy "${SERVICE_NAME}" \
  --image="${VLLM_IMAGE}" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --execution-environment=gen2 \
  --allow-unauthenticated \
  --cpu=8 \
  --memory=32Gi \
  --gpu=1 \
  --gpu-type="${GPU_TYPE}" \
  --no-gpu-zonal-redundancy \
  --no-cpu-throttling \
  --max-instances=1 \
  --concurrency="${CONCURRENCY}" \
  --timeout=600 \
  --startup-probe="tcpSocket.port=8080,initialDelaySeconds=240,failureThreshold=1,timeoutSeconds=240,periodSeconds=240" \
  --command="vllm" \
  --args="serve,${GCS_MODEL_PATH},--enable-chunked-prefill,--enable-prefix-caching,--generation-config=auto,--dtype=bfloat16,--max-num-seqs=${MAX_NUM_SEQS},--gpu-memory-utilization=0.95,--load-format=runai_streamer,--tensor-parallel-size=1,--port=8080,--host=0.0.0.0"

echo ""
echo "==> Getting service URL..."
VLLM_URL=$(gcloud run services describe "${SERVICE_NAME}" \
  --region="${REGION}" \
  --format="value(status.url)")

echo ""
echo "✓ vLLM service deployed!"
echo ""
echo "  Service URL : ${VLLM_URL}"
echo "  Models list : ${VLLM_URL}/v1/models"
echo ""
echo "==> Quick smoke test (model must be warm — first request may take ~4 min):"
echo ""
echo "  curl ${VLLM_URL}/v1/chat/completions \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"model\": \"${GCS_MODEL_PATH}\", \"messages\": [{\"role\": \"user\", \"content\": \"hi\"}]}'"
echo ""
echo "Set this in deploy/3_app_service.sh:"
echo "  VLLM_URL=\"${VLLM_URL}\""
echo "  MODEL_NAME=\"${GCS_MODEL_PATH}\""
