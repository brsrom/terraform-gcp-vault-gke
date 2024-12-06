#!/bin/bash

GKE_CLUSTER=$(terraform output -raw gke_cluster_name)
REGION=$(terraform output -raw region)

gcloud container clusters get-credentials $GKE_CLUSTER --region $REGION
kubectl cluster-info

