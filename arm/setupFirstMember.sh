#!/bin/bash

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

# Install Azure CLI 2.0
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ wheezy main" | \
     sudo tee /etc/apt/sources.list.d/azure-cli.list

sudo apt-key adv --keyserver packages.microsoft.com --recv-keys 417A0893
sudo apt-get install apt-transport-https
sudo apt-get update && sudo apt-get install azure-cli

# Install unzip
sudo apt-get install -y unzip

# Clone the source from remote location
cd /opt
git clone https://github.com/jjcollinge/quorum-deploy
cd quorum-deploy/source/

# Fetch the geth files from blob
az login --service-principal -u $AzureSPNAppId -p $AzureSPNPassword --tenant $AzureTenant
az account set -s $AzureSubscriptionId

export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
    --name $AzureBlobStorageName \
    --resource-group $AzureResourceGroup \
    | grep "connectionString" | awk '{ print $2 }')
az storage blob download -c node -n files.zip -f ./node.zip
unzip node.zip -d node

AzureTableStorageName=$AzureBlobStorageName
AzureTableStorageSas=$(az storage table generate-sas --name networkbootnodes --account-name $AzureBlobStorageName --permissions raud)

# Inject geth config values
sed -i -e "s/__AzureTableStorageName__/$AzureTableStorageName/g" node/config.json
sed -i -e "s/__AzureTableStorageSas__/$AzureTableStorageSas/g" node/config.json

# Copy files to local geth source
cp node/genesis.json geth/
mkdir -p geth/keys
cp node/key* geth/keys
cp node/config.json geth/config.json
cp node/config.json bootnode/config.json

# Inject constellation config values
sed -i -e "s/__OtherConstellationNodes__//g" constellation/node.conf

# Inject cakeshop config values
GethNetworkId=$(cat node/config.json | grep "GethNetworkId" | awk '{ print $2 }')
sed -i -e 's/__GethNetworkId__/'"$GethNetworkId"'/g' quorum-bootnode.yml

# [Re]build docker images if desired
if [[ "$Rebuild" = true ]]; then
  docker-compose -f quorum-bootnode.yml build
fi

# Bring up docker containers
docker-compose -f quorum-bootnode.yml up -d