#!/bin/bash
set -e

# -----------------------------
# Variables (edit as needed)
# -----------------------------
resourceGroup="acdnd-c4-project"
location="westus2"
clusterName="aks-cluster-001"

# Cloud Lab option (set to true if you're in Udacity/Cloud Lab)
isCloudLab=false

# Only used when isCloudLab=true (replace with your workspace Resource ID)
workspaceResourceId="/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/cloud-demo-153430/providers/Microsoft.OperationalInsights/workspaces/loganalytics-153430"

# -----------------------------
# Install kubectl via AKS CLI installer
# -----------------------------
echo "Installing kubectl (AKS CLI)..."
sudo az aks install-cli
echo "AKS CLI installed"

# -----------------------------
# Create Resource Group (optional)
# -----------------------------
echo "Creating resource group: $resourceGroup in $location"
az group create \
  --name "$resourceGroup" \
  --location "$location"

# -----------------------------
# Create AKS cluster
# -----------------------------
echo "Step 1 - Creating AKS cluster: $clusterName"

if [ "$isCloudLab" = true ]; then
  # Cloud Lab: create without monitoring addon first
  az aks create \
    --resource-group "$resourceGroup" \
    --name "$clusterName" \
    --node-count 1 \
    --generate-ssh-keys

  # Cloud Lab: enable monitoring using an existing Log Analytics workspace
  echo "Enabling monitoring addon using existing Log Analytics workspace..."
  az aks enable-addons \
    --resource-group "$resourceGroup" \
    --name "$clusterName" \
    --addons monitoring \
    --workspace-resource-id "$workspaceResourceId"
else
  # Personal Azure: can create with monitoring addon
  az aks create \
    --resource-group "$resourceGroup" \
    --name "$clusterName" \
    --node-count 1 \
    --enable-addons monitoring \
    --generate-ssh-keys
fi

echo "AKS cluster created: $clusterName"

# -----------------------------
# Connect to AKS cluster
# -----------------------------
echo "Step 2 - Getting AKS credentials..."
az aks get-credentials \
  --resource-group "$resourceGroup" \
  --name "$clusterName" \
  --overwrite-existing \
  --verbose

echo "Verifying connection to $clusterName"
kubectl get nodes

# -----------------------------
# Optional: deploy a sample app
# -----------------------------
# echo "Deploying sample app..."
# kubectl apply -f azure-vote.yaml