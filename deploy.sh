#!/usr/bin/env bash
# Reference: https://medium.com/@taylorhughes/how-to-deploy-an-existing-docker-container-project-to-google-cloud-run-with-the-minimum-amount-of-daca0b5978d8

export GCLOUD_PROJECT="sethsrobot" 
export REPO="docker-repo"
export REGION="us-central1"
export IMAGE="web-game-image"

export IMAGE_TAG=${REGION}-docker.pkg.dev/$GCLOUD_PROJECT/$REPO/$IMAGE

gcloud auth login

gcloud auth configure-docker us-central1-docker.pkg.dev

docker build -t $IMAGE_TAG -f Dockerfile --platform linux/x86_64 .

docker push $IMAGE_TAG