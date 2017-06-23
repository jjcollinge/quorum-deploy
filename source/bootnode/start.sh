#!/bin/bash

# This script will be executed on
# start up of the bootnode container
# image. It's responsible for configuring
# the bootnode client with the given parameters

# Settinng some logging variables
LOG_FILE="logs/start.log"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# Function definitions
function log ()
{
    echo "$TIMESTAMP $1" | tee -a $LOG_FILE
}

function ensureVarSet ()
{
    if [[ -z $1 ]]; then
        log "The environment variable $2 is not set, this is required!"
        exit 1
    fi
}

# Create log file if doesn't already exist
if [[ ! -f $LOG_FILE ]]; then
    LOG_DIR=$(dirname $LOG_FILE)
    mkdir -p $LOG_DIR
    touch $LOG_FILE
fi

# Start a local bootnode
touch "logs/bootnode.log"
nohup bootnode -genkey bootnode.key -addr "0.0.0.0:33445" > "logs/bootnode.log" 2>&1 &

# Wait for bootnode to start listening
log "Waiting for bootnode to start..."
for i in $(seq 1 6); do echo -ne "." 2>&1 > $LOG_FILE; sleep 1; done
echo "" 2>&1 > $LOG_FILE

log "Loading configuration file"
# Running some inline python to read values
# from the JSON configuration file
python << END
import json
import os
config_file = '/opt/quorum/config.json'
env_file = '/opt/quorum/env.sh'
with open(config_file, "r") as config_file:
    config = json.load(config_file)
with open(env_file, "w") as env_file:
    for key, value in config.items():
        key=key.upper()
        env_file.write("{0}=\"{1}\"\n".format(key, value))
END
source /opt/quorum/env.sh

# Define global constants
AZURE_STORAGE_TABLE="networkbootnodes"
AZURE_PARTITION_KEY=1494663149
AZURE_ROW_KEY=$GETHNETWORKID
HOST_PORT=33445
CONTAINERHOSTIP=$(curl -s -4 http://checkip.amazonaws.com || printf "0.0.0.0")
log "Configuring bootnode on $CONTAINERHOSTIP"

# Ensure all required varaibles are set
ensureVarSet $CONTAINERHOSTIP ${!CONTAINERHOSTIP@}
ensureVarSet $GETHNETWORKID ${!GETHNETWORKID@}
ensureVarSet $AZURETENANT ${!AZURETENANT@}
ensureVarSet $AZURESPNAPPID ${!AZURESPNAPPID@}
ensureVarSet $AZURESPNPASSWORD ${!AZURESPNPASSWORD@}
ensureVarSet $AZURESUBSCRIPTIONID ${!AZURESUBSCRIPTIONID@}
ensureVarSet $AZURETABLESTORAGENAME ${!AZURETABLESTORAGENAME@}
ensureVarSet $AZURETABLESTORAGESAS ${!AZURETABLESTORAGESAS@}

# Login to Azure Storage with SPN
log "Logging into Azure"
az login --service-principal -u $AZURESPNAPPID -p $AZURESPNPASSWORD --tenant $AZURETENANT 2>&1 >> "logs/azure.log"
az account set -s $AZURESUBSCRIPTIONID 2>&1 >> "logs/azure.log"

# Set storage account connection details
# ideally I'll remove this to use SAS but
# currently there is a bug with checking
# whether table exists
#suffix=${AZURETABLESTORAGENAME#storage}
#AzureResourceGroup=$(az group list | grep $suffix | grep "name" | awk '{ print $2 }' | tr -cd '[[:alnum:]]._-' )
#export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string --name $AZURETABLESTORAGENAME --resource-group $AzureResourceGroup | grep "connectionString" | awk '{ print $2 }')

# Grab the bootnode public key
LOCAL_BOOTNODE=$(grep -i "listening" "logs/bootnode.log" | awk '{print $5}' | head -n 1)
# If bootnode isn't up, try restarting
if [[ -z $LOCAL_BOOTNODE ]]; then
    log "Couldn't get local bootnode address"
    BIND_IN_USE=$(grep -i "in use" logs/bootnode.log | wc -l)
    if [[ $BIND_IN_USE -ge 1 ]]; then
        log "Trying to kill existing process"
        kill $(ps aux | grep "bootnode*" | awk '{print $2}')
        log "Starting new process"
        nohup bootnode -genkey bootnode.key -addr "0.0.0.0:33445" > "logs/bootnode.log" 2>&1 &
        sleep 6
        LOCAL_BOOTNODE=$(grep -i "listening" "logs/bootnode.log" | awk '{print $5}' | head -n 1)
        if [[ -z $LOCAL_BOOTNODE ]]; then
            log "Something isn't right, I can't start the bootnode process"
            exit 1
        fi
    fi
fi

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
    log "Registry is currently empty, initialising it with $LOCAL_ENODE"
    az storage entity insert -t $AZURE_STORAGE_TABLE -e PartitionKey=$AZURE_PARTITION_KEY RowKey=$AZURE_ROW_KEY Content=$LOCAL_ENODE $TABLE_ARGS 2>&1 >> "logs/azure.log"
else
    UPDATED_BOOTNODES="$CURRENT_BOOTNODES,$LOCAL_ENODE"
    log "Updating bootnode registry with $UPDATED_BOOTNODES"
    az storage entity replace -t $AZURE_STORAGE_TABLE -e PartitionKey=$AZURE_PARTITION_KEY RowKey=$AZURE_ROW_KEY Content=$UPDATED_BOOTNODES $TABLE_ARGS 2>&1 >> "logs/azure.log"
fi

# Keep container alive
echo "Sleeping indefinitely">>logs/start.log
tail -f /dev/null