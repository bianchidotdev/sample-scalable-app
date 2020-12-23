#!/usr/bin/env bash
set -e

SCRIPT_DIR=$(dirname $0)

APP_NAME=$1
IMAGE_NAME="michaeldbianchi/${APP_NAME}"

docker login
docker pull ${IMAGE_NAME} || echo "Image not found, building from scratch"

TIMESTAMP=$(date +"%Y%m%d%H%M")
SHORT_SHA=$(git rev-parse --short HEAD)

docker build -t ${IMAGE_NAME}:latest \
    -t ${IMAGE_NAME}:${SHORT_SHA} \
    -t ${IMAGE_NAME}:${TIMESTAMP} \
    --cache-from=${IMAGE_NAME} .

docker push ${IMAGE_NAME}

kubectl apply -f iac/manifests/${APP_NAME}.yaml

${SCRIPT_DIR}/trigger-app-update.sh ${APP_NAME}
