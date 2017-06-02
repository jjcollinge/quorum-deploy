#!/bin/bash

while getopts ":n:l:t:p:d:" opt; do
  case "$opt" in
    n) ResourceGroupPrefix="$OPTARG"
    ;;
    l) ResourceGroupLocation="$OPTARG"
    ;;
    t) TemplateFilePath="$OPTARG"
    ;;
    p) TemplateParametersFilePath="$OPTARG"
    ;;
    d) NodeDir="$OPTARG"
    ;;
  esac
done

function usage {
    echo "usage: $programname [-n resourcegroup ] [-l location ] [-t templatefile ] [-p parameterfile ] [-d node ]"
    echo "  -n resourcegroup     specify an azure resource group"
    echo "  -l location     specify an azure location"
    echo "  -t templatefile     specify an arm template file"
    echo "  -p parameterfile     specify an arm parameters file"
    echo "  -d node     specify a local node directory"
    exit 1
}

function info {
    echo
    echo "-------------------------------"
    echo $1
    echo "-------------------------------"
}

function error {
    >&2 echo $1
}

if [ -z "$ResourceGroupPrefix" ] || [ -z "$ResourceGroupLocation" ] || [ -z "$TemplateFilePath" ] || [ -z "$TemplateParametersFilePath" ] || [ -z "$NodeDir" ]; then
    usage
fi

# Check required files exists
if [[ ! -d $NodeDir ]]; then
    error "None existent node directory ($NodeDir) provided"
    exit 1
fi
if [[ ! -f "$NodeDir/genesis.json" ]]; then
    error "No genesis.json file provided"
    exit 1
fi

# Create zip of files
info "Creating zip"
zip -r node.zip $NodeDir

# Login into Azure
info "Logging into Azure"
AzureTenant=$(cat $NodeDir/config.json | grep "AzureTenant" | awk '{ print $2 }')
AzureTenant="${AzureTenant%\"*}"
AzureTenant=$(echo "$AzureTenant" | tr -d '",')
echo "AzureTenant: $AzureTenant"
AzureSPNAppId=$(cat $NodeDir/config.json | grep "AzureSPNAppId" | awk '{ print $2 }')
AzureSPNAppId="${AzureSPNAppId%\"*}"
AzureSPNAppId=$(echo "$AzureSPNAppId" | tr -d '",')
echo "AzureSPNAppId: $AzureSPNAppId"
AzureSPNPassword=$(cat $NodeDir/config.json | grep "AzureSPNPassword" | awk '{ print $2 }')
AzureSPNPassword="${AzureSPNPassword%\"*}"
AzureSPNPassword="${AzureSPNPassword#\"}"
echo "AzureSPNPassword: $AzureSPNPassword"
AzureSubscriptionId=$(cat $NodeDir/config.json | grep "AzureSubscriptionId" | awk '{ print $2 }')
AzureSubscriptionId="${AzureSubscriptionId%\"*}"
AzureSubscriptionId="${AzureSubscriptionId#\"}"
echo "AzureSubscriptionId: $AzureSubscriptionId"
echo

az login --service-principal -u $AzureSPNAppId -p $AzureSPNPassword --tenant $AzureTenant
az account set -s $AzureSubscriptionId

# Create resource group
RandomString=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 10 | head -n 1)
ResourceGroupName="$ResourceGroupPrefix$RandomString"
info "Creating resource group $ResourceGroupName"
az group create -n $ResourceGroupName -l $ResourceGroupLocation

# Create Storage Account
StorageName="storage$RandomString"
info "Creating storage account $StorageName"
az storage account create --name $StorageName\
                          --resource-group $ResourceGroupName\
                          --sku Standard_LRS

# Update parameters file
mkdir -p temp
TempParamsFile="temp/$ResourceGroupName.json"
cp $TemplateParametersFilePath $TempParamsFile
sed -i "s/__AzureBlobStorageName__/$StorageName/g" $TempParamsFile
sed -i "s/__AzureSPNAppId__/$AzureSPNAppId/g" $TempParamsFile
sed -i "s/__AzureSPNPassword__/$AzureSPNPassword/g" $TempParamsFile
sed -i "s/__AzureTenant__/$AzureTenant/g" $TempParamsFile
sed -i "s/__AzureSubscriptionId__/$AzureSubscriptionId/g" $TempParamsFile

# Set storage account connection string
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
    --name $StorageName \
    --resource-group $ResourceGroupName \
    | grep "connectionString" | awk '{ print $2 }')

# Create new blob storage container
info "Creating blob container"
az storage container create -n node

# Upload zip to blob container
info "Uploading blob"
az storage blob upload -f node.zip -c node -n files.zip

# Start ARM deployment
info "Starting Azure deployment"
echo "Template file: $TemplateFilePath"
echo "Parameters file: $TemplateParametersFilePath"
az group deployment create -g $ResourceGroupName --template-file "$TemplateFilePath" --parameters "@$TempParamsFile" --debug