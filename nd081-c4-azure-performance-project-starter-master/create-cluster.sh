#!/bin/bash
set -e

resourceGroup="acdnd-c4-project"
location="westus"
clusterName="udacity-cluster"

echo "Creating resource group: $resourceGroup in $location"
az group create --name "$resourceGroup" --location "$location"

echo "Creating AKS cluster: $clusterName"
az aks create \
  --resource-group "$resourceGroup" \
  --name "$clusterName" \
  --node-count 1 \
  --enable-addons monitoring \
  --generate-ssh-keys

echo "Getting credentials..."
az aks get-credentials \
  --resource-group "$resourceGroup" \
  --name "$clusterName" \
  --overwrite-existing

kubectl get nodes