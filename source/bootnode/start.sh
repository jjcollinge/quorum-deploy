#!/bin/bash

LOG_FILE="logs/start.log"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# Create log file if doesn't already exist
if [[ ! -f $LOG_FILE ]]; then
    LOG_DIR=$(dirname $LOG_FILE)
    mkdir -p $LOG_DIR
    touch $LOG_FILE
fi

function log ()
{
    echo "$TIMESTAMP $1" | tee -a $LOG_FILE
}

function ensureVarSet ()
{
    if [[ -z $1 ]]; then
        log "The environment variable ${!1@} is not set, this is required!"
        exit 1
    fi
}

# Start a local bootnode
nohup bootnode -genkey bootnode.key -addr "0.0.0.0:33445" 2>&1 > "logs/bootnode.log" &

# Wait for bootnode to start listening
log "Waiting for bootnode to start..."
for i in $(seq 1 6); do echo -ne "." 2>&1 > $LOG_FILE; sleep 1; done
echo "" 2>&1 > $LOG_FILE

# Load config
log "Loading configuration file"
rm -f /opt/bootnode/env.sh
python /opt/bootnode/loadconfig.py
source /opt/bootnode/env.sh

# Define global constants
AZURE_STORAGE_TABLE="networkbootnodes"
AZURE_PARTITION_KEY=1494663149
AZURE_ROW_KEY=$GETHNETWORKID
HOST_PORT=33445
CONTAINERHOSTIP=$(curl -s -4 http://checkip.amazonaws.com || printf "0.0.0.0")
log "Configuring bootnode on $CONTAINERHOSTIP"

# Ensure all required varaibles are set
ensureVarSet $CONTAINERHOSTIP
ensureVarSet $GETHNETWORKID
ensureVarSet $AZURETENANT
ensureVarSet $AZURESPNAPPID
ensureVarSet $AZURESUBSCRIPTIONID
ensureVarSet $AZURESPNPASSWORD
ensureVarSet $AZURETABLESTORAGENAME
ensureVarSet $AZURETABLESTORAGESAS

# Login to Azure Storage with SPN
log "Logging into Azure"
az login --service-principal -u $AZURESPNAPPID -p $AZURESPNPASSWORD --tenant $AZURETENANT 2>&1 >> "logs/azure.log"
az account set -s $AZURESUBSCRIPTIONID 2>&1 >> "logs/azure.log"

# Set storage account connection details
# ideally I'll remove this to use SAS but
# currently there is a bug with checking
# whether table exists
suffix=${AZURETABLESTORAGENAME#storage}
AzureResourceGroup=$(az group list | grep $suffix | grep "name" | awk '{ print $2 }' | tr -cd '[[:alnum:]]._-' )
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string --name $AZURETABLESTORAGENAME --resource-group $AzureResourceGroup | grep "connectionString" | awk '{ print $2 }')

# Grab the bootnode public key
attempts=0
LOCAL_BOOTNODE=$(grep -i "listening" logs/bootnode.log | awk '{print $5}' | head -n 1)
while ([[ -z $LOCAL_BOOTNODE ]]); do
    if [[ $attempts -ge 5 ]]; then
        log "Couldn't start local bootnode"
        exit 1
    fi
    ((attempts++))
    nohup bootnode -genkey bootnode.key -addr "0.0.0.0:33445" 2>&1 > "logs/bootnode.log" &
    sleep 6
    LOCAL_BOOTNODE=$(grep -i "listening" logs/bootnode.log | awk '{print $5}' | head -n 1)
done
log "Using bootnode public key: $LOCAL_BOOTNODE"

# Checking whether existing bootnode registry exists
log "Checking whether bootnode registry '$AZURE_STORAGE_TABLE' exists"
TABLE_ARGS="--account-name $AZURETABLESTORAGENAME --sas-token \"$AZURETABLESTORAGESAS\""
exists=$(az storage table exists --name $AZURE_STORAGE_TABLE $TABLE_ARGS)

if [[ $exists == *"false"* ]]; then
    # Registry doesn't exist, creating one
    log "No existing bootnode registry, creating new one called '$AZURE_STORAGE_TABLE'"
    az storage table create --name $AZURE_STORAGE_TABLE 2>&1 >> "logs/azure.log"
else
    # Registry already exists, no need to create one
    log "Existing bootnode registry found"
fi

# Fetch any existing bootnodes in the registry
log "Fetching existing bootnodes from registry"
RESPONSE=$(az storage entity show -t $AZURE_STORAGE_TABLE --partition-key $AZURE_PARTITION_KEY --row-key $AZURE_ROW_KEY $TABLE_ARGS | grep -e "enode://" | awk '{ print $2 }')
CURRENT_BOOTNODES=${RESPONSE:1:-2}
log "Found: $CURRENT_BOOTNODES"

# Format the local bootnode address correctly with external ip
LOCAL_ENODE="${LOCAL_BOOTNODE/::/$CONTAINERHOSTIP}"
LOCAL_ENODE="${LOCAL_ENODE//[}"
LOCAL_ENODE="${LOCAL_ENODE//]}"
CONTAINER_PORT=$(echo "$LOCAL_ENODE" | awk -F: '{print $3}')
LOCAL_ENODE="${LOCAL_ENODE/$CONTAINER_PORT/$HOST_PORT}"
log "Formatted local bootnode: $LOCAL_ENODE"

# Update bootnode registry with local bootnode
if [[ -z $CURRENT_BOOTNODES ]]; then
    echo "Registry is currently empty, initialising it with $LOCAL_ENODE">>logs/start.log
    az storage entity insert -t $AZURE_STORAGE_TABLE -e PartitionKey=$AZURE_PARTITION_KEY RowKey=$AZURE_ROW_KEY Content=$LOCAL_ENODE $TABLE_ARGS 2>&1 >> "logs/azure.log"
else
    UPDATED_BOOTNODES="$CURRENT_BOOTNODES,$LOCAL_ENODE"
    echo "Updating bootnode registry with $UPDATED_BOOTNODES">>logs/start.log
    az storage entity replace -t $AZURE_STORAGE_TABLE -e PartitionKey=$AZURE_PARTITION_KEY RowKey=$AZURE_ROW_KEY Content=$UPDATED_BOOTNODES $TABLE_ARGS 2>&1 >> "logs/azure.log"
fi

# Keep container alive
echo "Sleeping indefinitely">>logs/start.log
tail -f /dev/null