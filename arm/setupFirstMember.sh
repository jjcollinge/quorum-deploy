#!/bin/bash

# Handle arguments...
# This script is intended to be called
# from the ARM template and thus the 
# argument flags don't really matter.
while getopts ":a:b:c:d:e:f:g:" opt; do
  case "$opt" in
    a) AzureTenant="$OPTARG"
    ;;
    b) AzureSPNAppId="$OPTARG"
    ;;
    c) AzureSPNPassword="$OPTARG"
    ;;
    d) AzureSubscriptionId="$OPTARG"
    ;;
    e) AzureResourceGroup="$OPTARG"
    ;;
    f) AzureBlobStorageName="$OPTARG"
    ;;
    g) Rebuild="$OPTARG"
    ;;
  esac
done

# Set variables relating to logging
BASEDIR=$(pwd)
EPOCH=$(date +%s)
LOG_FILE="$BASEDIR/run$EPOCH.log"
touch $LOG_FILE
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

function log () {
    echo "$TIMESTAMP $1" | tee -a $LOG_FILE
}

log "Starting first member setup"

# Validate required parameters are set
if [[ -z $AzureTenant ]] ||
   [[ -z $AzureSPNAppId ]] ||
   [[ -z $AzureSPNPassword ]] ||
   [[ -z $AzureSubscriptionId ]] ||
   [[ -z $AzureResourceGroup ]] ||
   [[ -z $AzureBlobStorageName ]]; then
   log "Fatal error: required parameter is not provided"
fi

# Check whether az cli is installed
if [[ $(dpkg -l | grep az | wc -l) == 0 ]]; then
  # Doesn't look like it, let's install it now
  log "Installing Azure CLI 2.0"
  echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ wheezy main" | \
      tee /etc/apt/sources.list.d/azure-cli.list
  apt-key adv --keyserver packages.microsoft.com --recv-keys 417A0893
  apt-get install -y apt-transport-https
  apt-get update && apt-get install -y azure-cli
fi

# Check whether unzip is installed
if [[ $(dpkg -l | grep unzip | wc -l) == 0 ]]; then
  # Doesn't look like it, let's install it now
  log "Installing zip"
  apt-get install -y unzip
fi

# Clone the source from remote repository
log "Cloning source code repository"
git clone https://github.com/jjcollinge/quorum-deploy /opt/quorum-deploy
cd /opt/quorum-deploy/source/

# Logging into Azure
log "Logging into Azure"
az login --service-principal -u $AzureSPNAppId -p $AzureSPNPassword --tenant $AzureTenant 2>&1 >> $LOG_FILE
log "Switching Azure subscription to $AzureSubscriptionId"
az account set -s $AzureSubscriptionId 2>&1 >> $LOG_FILE

# Fetching node archive from blob
log "Setting Azure storage connection string"
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
    --name $AzureBlobStorageName \
    --resource-group $AzureResourceGroup \
    | grep "connectionString" | awk '{ print $2 }')

log "Downloading node configuration archive from blob"
az storage blob download -c node -n files.zip -f /opt/quorum-deploy/node.zip 2>&1 >> $LOG_FILE
log "Expanding archive"
mkdir -p /opt/quorum-deploy/node
unzip /opt/quorum-deploy/node.zip -d /opt/quorum-deploy/node 2>&1 >> $LOG_FILE
# Check node was expanded correctly
if [ "$(ls -A /opt/quorum-deploy/node)" ]; then
  log "Node expanded successfully"
else
  log "Node is empty, something went wrong"
  exit 1
fi

# Create an Azure storage table
log "Creating Azure storage table for bootnode registry"
AzureTableStorageName=$AzureBlobStorageName
az storage table create -n networkbootnodes 2>&1 >> $LOG_FILE
dateVar=$(TZ=UTC date +"%Y-%m-%dT%H:%MZ" -d "+5 days")
log "Generating SAS token for bootnode registry table"
AzureTableStorageSas=$(az storage account generate-sas --account-name $AzureTableStorageName --expiry ${dateVar} --permissions ldpruwac --resource-types sco --services t --output tsv)

# Add Azure storage table details into node config file
log "Adding azure storage table access details into node's config file if not present"
if ! grep -q "AzureTableStorageName" /opt/quorum-deploy/node/config.json; then
# Running some inline python to handle JSON manipulation
python << END
import json
import sys
config_file = '/opt/quorum-deploy/node/config.json'
with open(config_file, 'r') as json_file:
  json_decoded = json.load(json_file)
json_decoded["AzureTableStorageName"] = "$AzureTableStorageName"
json_decoded["AzureTableStorageSas"] = "$AzureTableStorageSas"
with open(config_file, 'w') as json_file:
  json.dump(json_decoded, json_file, indent=4, separators=(',', ': '))
END
fi

# Copy geth files to local geth directory
log "Copying files to local Geth directory"
cp /opt/quorum-deploy/node/geth/genesis.json /opt/quorum-deploy/source/geth/
mkdir -p /opt/quorum-deploy/source/geth/keys
cp /opt/quorum-deploy/node/geth/key* /opt/quorum-deploy/source/geth/keys
cp /opt/quorum-deploy/node/config.json /opt/quorum-deploy/source/geth/config.json
cp /opt/quorum-deploy/node/config.json /opt/quorum-deploy/source/bootnode/config.json

# Copy constellation files to local constellation directory
log "Copying files to local Constellation directory"
cp /opt/quorum-deploy/node/constellation/node*.pub /opt/quorum-deploy/node/constellation/node*.key /opt/quorum-deploy/source/constellation/keys

# Inject constellation config values
log "Injecting constellation configuration values"
sed -i -e "s/__OtherConstellationNodes__//g" /opt/quorum-deploy/source/constellation/node.conf

# Inject cakeshop config values
log "Injecting cakeshop config values"
GethNetworkId=$(cat /opt/quorum-deploy/node/config.json | grep "GethNetworkId" | awk '{ print $2 }' | sed 's/[^0-9]*//g')
GethNodeIP=$(curl -s -4 http://checkip.amazonaws.com || printf "0.0.0.0")
#sed -i -e 's/__GethNodeIP__/'"$GethNodeIP"'/g' /opt/quorum-deploy/source/quorum-bootnode.yml
sed -i -e 's/__GethNodeIP__/'"$GethNodeIP"'/g' /opt/quorum-deploy/source/cakeshop/application.properties
sed -i -e 's/__GethNetworkId__/'"$GethNetworkId"'/g' /opt/quorum-deploy/source/cakeshop/application.properties

# [Re]build docker images if desired
if [[ "$Rebuild" = true ]]; then
  log "Building docker images from scratch, this may take a while!"
  docker-compose -f /opt/quorum-deploy/source/quorum-bootnode.yml build
fi

# Bring up docker containers
log "Ok, here we go, I'm bringing up the docker containers..."
docker-compose -f /opt/quorum-deploy/source/quorum-bootnode.yml up -d