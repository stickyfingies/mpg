#!/usr/bin/env bash

export GCLOUD_PROJECT="sethsrobot" 
export REPO="docker-repo"
export REGION="us-central1"
export IMAGE="web-game-image"

export IMAGE_TAG=${REGION}-docker.pkg.dev/$GCLOUD_PROJECT/$REPO/$IMAGE

gcloud auth login

gcloud compute instances \
    create web-game \
    --image ${IMAGE_TAG} \
    --zone us-central1-a \
    --machine-type e2-micro