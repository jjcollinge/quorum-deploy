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

# Check required variables are set
if [ -z "$ResourceGroupPrefix" ] || [ -z "$ResourceGroupLocation" ] || [ -z "$TemplateFilePath" ] || [ -z "$TemplateParametersFilePath" ] || [ -z "$NodeDir" ]; then
    usage
fi

EPOCH=$(date +%s)
mkdir -p logs
LOG_FILE="logs/deploy$EPOCH.log"
touch $LOG_FILE
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

function log () {
    echo "$TIMESTAMP $1" | tee -a $LOG_FILE
}

# Check required files exists
if [[ ! -d $NodeDir ]]; then
    log "None existent node directory ($NodeDir) provided"
    exit 1
fi
if [[ ! -f "$NodeDir/genesis.json" ]]; then
    log "No genesis.json file provided"
    exit 1
fi

# Create zip of files
log "Creating zip archive of node directory $NodeDir"
zip -r node.zip $NodeDir

# Getting Azure details from node config file
log "Grabbing Azure details from config file"
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

log "Logging into Azure with service principal"
az login --service-principal -u $AzureSPNAppId -p $AzureSPNPassword --tenant $AzureTenant 2>&1 >> $LOG_FILE
log "Switching to subscription $AzureSubscriptionId"
az account set -s $AzureSubscriptionId 2>&1 >> $LOG_FILE

# Create resource group
RandomString=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 10 | head -n 1)
ResourceGroupName="$ResourceGroupPrefix$RandomString"
log "Creating Azure resource group $ResourceGroupName"
az group create -n $ResourceGroupName -l $ResourceGroupLocation 2>&1 >> $LOG_FILE

# Create storage account
StorageName="storage$RandomString"
log "Creating storage account $StorageName"
az storage account create --name $StorageName\
                          --resource-group $ResourceGroupName\
                          --sku Standard_LRS 2>&1 >> $LOG_FILE

# Create a temporary copy of the template params file
# and inject provided parameter values
log "Creating temporary template file"
mkdir -p temp
TempParamsFile="temp/$ResourceGroupName.json"
cp $TemplateParametersFilePath $TempParamsFile
sed -i "s/__AzureBlobStorageName__/$StorageName/g" $TempParamsFile
sed -i "s/__AzureSPNAppId__/$AzureSPNAppId/g" $TempParamsFile
sed -i "s/__AzureSPNPassword__/$AzureSPNPassword/g" $TempParamsFile
sed -i "s/__AzureTenant__/$AzureTenant/g" $TempParamsFile
sed -i "s/__AzureSubscriptionId__/$AzureSubscriptionId/g" $TempParamsFile

# Set storage account connection string
log "Setting storage account connection string"
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
    --name $StorageName \
    --resource-group $ResourceGroupName \
    | grep "connectionString" | awk '{ print $2 }')

# Create new blob storage container
log "Creating azure storage blob container"
az storage container create -n node 2>&1 >> $LOG_FILE

# Upload zip to blob container
log "Uploading archive to azure storage blob container"
az storage blob upload -f node.zip -c node -n files.zip 2>&1 >> $LOG_FILE

# Start ARM deployment
log "Starting Azure resource group deployment"
echo "Template file: $TemplateFilePath"
echo "Parameters file: $TemplateParametersFilePath"
az group deployment create -g $ResourceGroupName --template-file "$TemplateFilePath" --parameters "@$TempParamsFile" --debug 2>&1 >> $LOG_FILE