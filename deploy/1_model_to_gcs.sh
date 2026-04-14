#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Step 1 — Download Gemma 4 from HuggingFace and upload to GCS
#
# Run this ONCE before deploying vLLM.
# You need:
#   - gcloud CLI authenticated  (gcloud auth login)
#   - A HuggingFace token with access to google/gemma-4-*
#     Get one at https://huggingface.co/settings/tokens
#     Accept the Gemma 4 license at https://huggingface.co/google/gemma-4-E2B-it
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Config — edit these ───────────────────────────────────────────────────────
PROJECT_ID="valued-mediator-461216-k7"
REGION="us-central1"
GCS_BUCKET="${PROJECT_ID}-gemma4-models"
HF_TOKEN="${HF_TOKEN:?Set HF_TOKEN env var before running: export HF_TOKEN=hf_...}"

MODEL_ID="google/gemma-4-E2B-it"
MODEL_DIR="gemma-4-E2B-it"
# ─────────────────────────────────────────────────────────────────────────────

echo "==> Setting project: ${PROJECT_ID}"
gcloud config set project "${PROJECT_ID}"

echo "==> Creating GCS bucket: gs://${GCS_BUCKET}"
gcloud storage buckets create "gs://${GCS_BUCKET}" \
  --location="${REGION}" \
  --uniform-bucket-level-access \
  --quiet 2>/dev/null || echo "    (bucket already exists, continuing)"

echo "==> Granting Storage Object Viewer to Cloud Run service account"
PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")
gcloud storage buckets add-iam-policy-binding "gs://${GCS_BUCKET}" \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role="roles/storage.objectViewer"

echo "==> Installing huggingface_hub (if not already installed)"
pip install -q huggingface_hub

echo "==> Downloading model: ${MODEL_ID}"
echo "    This can take 10-30 minutes depending on your connection."
python3 - <<PYEOF
from huggingface_hub import snapshot_download
snapshot_download(
    repo_id="${MODEL_ID}",
    local_dir="/tmp/${MODEL_DIR}",
    token="${HF_TOKEN}",
    ignore_patterns=["*.msgpack", "*.h5", "flax_*"],
)
print("Download complete.")
PYEOF

echo "==> Uploading to GCS: gs://${GCS_BUCKET}/models/${MODEL_DIR}/"
echo "    This can take 10-20 minutes."
gcloud storage cp "/tmp/${MODEL_DIR}/" "gs://${GCS_BUCKET}/models/${MODEL_DIR}/" \
  --recursive

echo ""
echo "✓ Done. Model is at: gs://${GCS_BUCKET}/models/${MODEL_DIR}"
echo ""
echo "Set this in deploy/2_vllm_service.sh:"
echo "  GCS_MODEL_PATH=\"gs://${GCS_BUCKET}/models/${MODEL_DIR}\""
