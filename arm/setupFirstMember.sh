#!/bin/bash

while getopts ":a:b:c:d:e:f:" opt; do
  case "$opt" in
    a) AzureTenant="$OPTARG"
    ;;
    b) AzureSPNAppId="$OPTARG"
    ;;
    c) AzureSPNPassword="$OPTARG"
    ;;
    d) AzureResourceGroup="$OPTARG"
    ;;
    e) AzureBlobStorageName="$OPTARG"
    ;;
    f) Rebuild="$OPTARG"
    ;;
  esac
done

# Clone the source from remote location
cd /opt
git clone https://github.com/jjcollinge/quorum-deploy
cd quorum-deploy/source/

# Fetch the geth files from blob
az login --service-principal -u $AzureSPNAppId -p $AzureSPNPassword --tenant $AzureTenant
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