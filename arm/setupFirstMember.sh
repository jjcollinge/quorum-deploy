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

if [[ $(dpkg -l | grep az | wc -l) == 0 ]]; then
  # Install azure cli 2.0
  echo "Installing Azure CLI 2.0" | tee setup.log
  echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ wheezy main" | \
      tee /etc/apt/sources.list.d/azure-cli.list

  apt-key adv --keyserver packages.microsoft.com --recv-keys 417A0893
  apt-get install -y apt-transport-https
  apt-get update && apt-get install -y azure-cli
fi

if [[ $(dpkg -l | grep unzip | wc -l) == 0 ]]; then
  # Install unzip
  echo "Installing unzip" | tee setup.log
  apt-get install -y unzip
fi

# Clone the source from remote location
echo "Cloning source repo" | tee setup.log
cd /opt
git clone https://github.com/jjcollinge/quorum-deploy
cd quorum-deploy/source/

# Fetch the geth files from blob
echo "Fetching geth files from blob" | tee setup.log
az login --service-principal -u $AzureSPNAppId -p $AzureSPNPassword --tenant $AzureTenant
az account set -s $AzureSubscriptionId

echo "Downloading blob" | tee setup.log
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
    --name $AzureBlobStorageName \
    --resource-group $AzureResourceGroup \
    | grep "connectionString" | awk '{ print $2 }')
az storage blob download -c node -n files.zip -f /opt/quorum-deploy/node.zip
unzip /opt/quorum-deploy/node.zip -d /opt/quorum-deploy

# Generate a sas token for table storage
echo "Generating SAS token for table storage" | tee setup.log
AzureTableStorageName=$AzureBlobStorageName
AzureTableStorageSas=$(az storage table generate-sas --name networkbootnodes --account-name $AzureBlobStorageName --permissions raud)

# Inject table storage details if not provided (i.e. is firstMember)
echo "Injecting values into config" | tee setup.log
if ! grep -q "AzureTableStorageName" /opt/quorum-deploy/node/config.json; then
python << END
import json
import sys
config_file = '/opt/quorum-deploy/node/config.json'
with open(config_file, 'r') as json_file:
  json_decoded = json.load(json_file)
json_decoded["AzureTableStorageName"] = "$AzureTableStorageName"
json_decoded["AzureTableStorageSas"] = $AzureTableStorageSas
with open(config_file, 'w') as json_file:
  json.dump(json_decoded, json_file, indent=4, separators=(',', ': '))
END
fi
echo "New config..."
cat /opt/quorum-deploy/node/config.json

# Copy files to local geth source
echo "Copying files to local geth source" | tee setup.log
cp /opt/quorum-deploy/node/genesis.json /opt/quorum-deploy/source/geth/
mkdir -p /opt/quorum-deploy/source/geth/keys
cp /opt/quorum-deploy/node/key* /opt/quorum-deploy/source/geth/keys
cp /opt/quorum-deploy/node/config.json /opt/quorum-deploy/source/geth/config.json
cp /opt/quorum-deploy/node/config.json /opt/quorum-deploy/source/bootnode/config.json

# Inject constellation config values
sed -i -e "s/__OtherConstellationNodes__//g" /opt/quorum-deploy/source/constellation/node.conf

# Inject cakeshop config values
GethNetworkId=$(cat /opt/quorum-deploy/node/config.json | grep "GethNetworkId" | awk '{ print $2 }' | sed 's/[^0-9]*//g')
sed -i -e 's/__GethNetworkId__/'"$GethNetworkId"'/g' /opt/quorum-deploy/source/quorum-bootnode.yml

# [Re]build docker images if desired
if [[ "$Rebuild" = true ]]; then
  echo "Building docker images" | tee setup.log
  docker-compose -f /opt/quorum-deploy/source/quorum-bootnode.yml build
fi

# Bring up docker containers
echo "Bringing up docker containers..." | tee setup.log
docker-compose -f /opt/quorum-deploy/source/quorum-bootnode.yml up -d