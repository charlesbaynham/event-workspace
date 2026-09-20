#!/usr/bin/env bash
# One-paste Google Cloud setup for the gsheets skill.
#
# Run this in Google Cloud Shell (https://shell.cloud.google.com) -- it is
# already authenticated as you, so there is nothing to log into and no
# console clicking. Paste the whole thing, press enter, wait ~60s.
#
# It creates a project, turns on the Sheets and Drive APIs, makes a service
# account, and prints its JSON key. Everything here is free; the Sheets API
# has no billing requirement.

set -euo pipefail

PROJECT_ID="${PROJECT_ID:-claude-sheets-$(date +%s | tail -c 7)}"
SA_NAME="${SA_NAME:-claude-sheets}"

echo "==> Creating project ${PROJECT_ID}"
if ! gcloud projects create "${PROJECT_ID}" --name="Claude Sheets" 2>/dev/null; then
  echo "    Could not create a project (quota, or the ID is taken)."
  echo "    Set PROJECT_ID to an existing project and re-run, e.g.:"
  echo "      PROJECT_ID=my-existing-project bash bootstrap_gcp.sh"
  gcloud projects list --format="table(projectId,name)" || true
  exit 1
fi

gcloud config set project "${PROJECT_ID}" --quiet

echo "==> Enabling Sheets + Drive APIs (this is the slow part)"
gcloud services enable sheets.googleapis.com drive.googleapis.com --quiet

echo "==> Creating service account ${SA_NAME}"
gcloud iam service-accounts create "${SA_NAME}" \
  --display-name="Claude Sheets" --quiet

SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "==> Minting key"
gcloud iam service-accounts keys create /tmp/sa.json \
  --iam-account="${SA_EMAIL}" --quiet

cat <<EOF

================================================================
 Service account address -- share your spreadsheets with this,
 as an Editor, or nothing below will have permission to work:

   ${SA_EMAIL}

================================================================
 JSON key follows. Treat it like a password: anyone holding it
 can reach every sheet you share with the address above. It
 grants no access to the rest of your Drive.
================================================================

EOF

cat /tmp/sa.json
echo
echo "Key also saved to /tmp/sa.json in this Cloud Shell."
echo "Revoke any time with:"
echo "  gcloud iam service-accounts delete ${SA_EMAIL} --project=${PROJECT_ID}"
