#!/usr/bin/env bash

set -e

PROJECT_ID="example-project"  # fill in your Google project ID here
GSA_NAME="breeze-ds"
NAMESPACE="default"
KSA_NAME="breeze-ds"

declare -a ROLES=("roles/compute.admin" "roles/monitoring.viewer" "roles/monitoring.metricWriter" "roles/logging.logWriter" "roles/iam.serviceAccountUser")

gcloud iam service-accounts create $GSA_NAME --project=$PROJECT_ID

for role in "${ROLES[@]}"
do
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member "serviceAccount:${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role "$role"
done

gcloud iam service-accounts add-iam-policy-binding ${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:${PROJECT_ID}.svc.id.goog[${NAMESPACE}/${KSA_NAME}]"