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

if [ -z "$ResourceGroupPrefix" ] || [ -z "$ResourceGroupLocation" ] || [ -z "$TemplateFilePath" ] || [ -z "$TemplateParametersFilePath" ] || [ -z "$NodeDir" ]; then
    echo "Usage:"
    echo "------"
    echo "Required arguments: -n, -l, -t, -p, -d"
    echo
    echo "-n : Azure resource group name"
    echo "-l : Azure resource group location"
    echo "-t : ARM template file path"
    echo "-p : ARM template parameters file path"
    echo "-d : Local node directory"
    exit 1
fi

# Check required files exists
if [[ ! -d $NodeDir ]]; then
    echo "None existent node directory ($NodeDir) provided"
fi
if [[ ! -f node/gensis.json ]]; then
    echo "No genesis.json file provided"
fi

# Create zip of files
echo "Creating zip"
zip -r node.zip $NodeDir

# Login into Azure
echo "Logging into Azure"
az login

# Create resource group
RandomString=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 10 | head -n 1)
ResourceGroupName="$ResourceGroupPrefix$RandomString"
echo "Creating resource group $ResourceGroupName"
az group create -n $ResourceGroupName -l $ResourceGroupLocation

# Create Storage Account
StorageName="storage$RandomString"
echo "Creating storage account $StorageName"
az storage account create --name $StorageName\
                          --resource-group $ResourceGroupName\
                          --sku Standard_LRS

# Update parameters file
mkdir -p temp
TempParamsFile="temp/$ResourceGroupName.json"
cp $TemplateParametersFilePath $TempParamsFile
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
sed -i "s/__AzureBlobStorageName__/$StorageName/g" $TempParamsFile
sed -i "s/__AzureSPNAppId__/$AzureSPNAppId/g" $TempParamsFile
sed -i "s/__AzureSPNPassword__/$AzureSPNPassword/g" $TempParamsFile
sed -i "s/__AzureTenant__/$AzureTenant/g" $TempParamsFile

# Set storage account connection string
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
    --name $StorageName \
    --resource-group $ResourceGroupName \
    | grep "connectionString" | awk '{ print $2 }')

# Create new blob storage container
echo "Creating blob container"
az storage container create -n node

# Upload zip to blob container
echo "Uploading blob"
az storage blob upload -f node.zip -c node -n files.zip

# Start ARM deployment
echo "Starting Azure deployment"
echo "Template file: $TemplateFilePath"
echo "Parameters file: $TemplateParametersFilePath"
az group deployment create -g $ResourceGroupName --template-file "$TemplateFilePath" --parameters "@$TempParamsFile" --debug