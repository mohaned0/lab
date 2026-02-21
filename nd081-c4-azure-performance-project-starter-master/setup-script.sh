#!/bin/bash
set -e

# -----------------------------
# Variables
# -----------------------------
resourceGroup="acdnd-c4-project"
location="westus"

osType="Ubuntu2204"
vmssName="udacity-vmss"
adminName="udacityadmin"

# Storage (optional for diagnostics/labs)
storageAccount="udacitydiag$RANDOM"
storageType="Standard_LRS"

# Network
vmSize="Standard_B1s"
vnetName="$vmssName-vnet"
subnetName="$vnetName-subnet"
nsgName="$vmssName-nsg"

# Load Balancer
lbName="$vmssName-lb"
pipName="pip-$lbName"
bePoolName="$vmssName-bepool"
probeName="tcpProbe"
lbRule="$lbName-network-rule"

# -----------------------------
# Create Resource Group
# -----------------------------
echo "STEP 0 - Creating resource group: $resourceGroup"
az group create \
  --name "$resourceGroup" \
  --location "$location"

# -----------------------------
# Create Storage Account (optional)
# -----------------------------
echo "STEP 1 - Creating storage account: $storageAccount"
az storage account create \
  --name "$storageAccount" \
  --resource-group "$resourceGroup" \
  --location "$location" \
  --sku "$storageType"

# -----------------------------
# Create VNet and Subnet
# -----------------------------
echo "STEP 2 - Creating VNet/Subnet: $vnetName / $subnetName"
az network vnet create \
  --resource-group "$resourceGroup" \
  --name "$vnetName" \
  --address-prefix 10.0.0.0/16 \
  --subnet-name "$subnetName" \
  --subnet-prefix 10.0.0.0/24

# -----------------------------
# Create Network Security Group + Rules
# -----------------------------
echo "STEP 3 - Creating NSG: $nsgName"
az network nsg create \
  --resource-group "$resourceGroup" \
  --name "$nsgName"

echo "STEP 3.1 - Adding NSG rule: Allow HTTP (80)"
az network nsg rule create \
  --resource-group "$resourceGroup" \
  --nsg-name "$nsgName" \
  --name Allow_HTTP_80 \
  --priority 100 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes Internet \
  --source-port-ranges "*" \
  --destination-address-prefixes "*" \
  --destination-port-ranges 80

echo "STEP 3.2 - Adding NSG rule: Allow SSH (22)"
# Tip: for better security, replace Internet with your public IP/CIDR.
az network nsg rule create \
  --resource-group "$resourceGroup" \
  --nsg-name "$nsgName" \
  --name Allow_SSH_22 \
  --priority 110 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes Internet \
  --source-port-ranges "*" \
  --destination-address-prefixes "*" \
  --destination-port-ranges 22

echo "STEP 3.3 - Associating NSG with subnet"
az network vnet subnet update \
  --resource-group "$resourceGroup" \
  --vnet-name "$vnetName" \
  --name "$subnetName" \
  --network-security-group "$nsgName"

# -----------------------------
# Create Public IP + Load Balancer + Backend Pool
# -----------------------------
echo "STEP 4 - Creating Public IP: $pipName"
az network public-ip create \
  --resource-group "$resourceGroup" \
  --name "$pipName" \
  --sku Standard \
  --allocation-method Static

echo "STEP 5 - Creating Load Balancer: $lbName (backend pool: $bePoolName)"
az network lb create \
  --resource-group "$resourceGroup" \
  --name "$lbName" \
  --sku Standard \
  --public-ip-address "$pipName" \
  --frontend-ip-name LoadBalancerFrontEnd \
  --backend-pool-name "$bePoolName"

echo "STEP 6 - Creating Health Probe: $probeName"
az network lb probe create \
  --resource-group "$resourceGroup" \
  --lb-name "$lbName" \
  --name "$probeName" \
  --protocol tcp \
  --port 80 \
  --interval 5 \
  --threshold 2

echo "STEP 7 - Creating LB Rule: $lbRule (80 -> 80)"
az network lb rule create \
  --resource-group "$resourceGroup" \
  --lb-name "$lbName" \
  --name "$lbRule" \
  --protocol tcp \
  --frontend-ip-name LoadBalancerFrontEnd \
  --frontend-port 80 \
  --backend-pool-name "$bePoolName" \
  --backend-port 80 \
  --probe-name "$probeName"

# -----------------------------
# Create VM Scale Set (attached to LB + VNet/Subnet)
# -----------------------------
echo "STEP 8 - Creating VM Scale Set: $vmssName"
az vmss create \
  --resource-group "$resourceGroup" \
  --name "$vmssName" \
  --location "$location" \
  --orchestration-mode Uniform \
  --image "$osType" \
  --vm-sku "$vmSize" \
  --instance-count 2 \
  --admin-username "$adminName" \
  --generate-ssh-keys \
  --custom-data cloud-init.txt \
  --upgrade-policy-mode automatic \
  --vnet-name "$vnetName" \
  --subnet "$subnetName" \
  --lb "$lbName" \
  --backend-pool-name "$bePoolName" \
  --lb-sku Standard

# -----------------------------
# Output Public IP for testing
# -----------------------------
lbIp=$(az network public-ip show -g "$resourceGroup" -n "$pipName" --query ipAddress -o tsv)
echo "✅ VMSS + Load Balancer deployment completed!"
echo "🌍 Load Balancer Public IP: $lbIp"
echo "Try: http://$lbIp"