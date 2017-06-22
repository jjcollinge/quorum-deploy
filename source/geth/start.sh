#!/bin/bash

# This script will be executed on
# start up of the geth container
# image. It's responsible for configuring
# the geth client with the given parameters

# Settinng some logging variables
LOG_FILE="temp/logs/start.log"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# Function definitions
function log ()
{
    echo "$TIMESTAMP $1" | tee -a $LOG_FILE
}

function terminate()
{
    log "Fatal error"
    log "Command: $1"
    exit 1
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

log "Starting geth initialisation"


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
BOOTNODE_PORT=33445
BLOB_CONTAINER="node"
BLOB_FILE="files.zip"
KEYSTORE="/opt/quorum/data/keystore"

# Ensure all required varaibles are set
ensureVarSet $GETHNETWORKID ${!GETHNETWORKID@}
ensureVarSet $AZURETENANT ${!AZURETENANT@}
ensureVarSet $AZURESPNAPPID ${!AZURESPNAPPID@}
ensureVarSet $AZURESPNPASSWORD ${!AZURESPNPASSWORD@}
ensureVarSet $AZURESUBSCRIPTIONID ${!AZURESUBSCRIPTIONID@}
ensureVarSet $AZURETABLESTORAGENAME ${!AZURETABLESTORAGENAME@}
ensureVarSet $AZURETABLESTORAGESAS ${!AZURETABLESTORAGESAS@}

# Login to Azure Storage with SPN
log "Logging into Azure"
az login --service-principal -u $AZURESPNAPPID -p $AZURESPNPASSWORD --tenant $AZURETENANT 2>&1 >> $LOG_FILE
az account set -s $AZURESUBSCRIPTIONID 2>&1 >> $LOG_FILE

# Set storage account connection details
# ideally I'll remove this to use SAS but
# currently there is a bug with checking
# whether table exists
suffix=${AZURETABLESTORAGENAME#storage}
AzureResourceGroup=$(az group list | grep $suffix | grep "name" | awk '{ print $2 }' | tr -cd '[[:alnum:]]._-' )
if [[ $? -ne 0 ]]; then terminate !!
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string --name $AZURETABLESTORAGENAME --resource-group $AzureResourceGroup | grep "connectionString" | awk '{ print $2 }')

# Initialise Geth client
log "Initialising geth"
geth --datadir /opt/quorum/data init genesis.json
if [[ $? -ne 0 ]]; then terminate !!

# Copy key files into geth's keystore
log "Copying key files to keystore"
for KEY in "keys/key*"; do
    cp $KEY $KEYSTORE
done

# Check bootnode registry exists
log "Checking whether bootnode registry '$AZURE_STORAGE_TABLE' exists"
table_args="--account-name $AZURETABLESTORAGENAME --sas-token $AZURETABLESTORAGESAS"
exists=$(az storage table exists --name $AZURE_STORAGE_TABLE $table_args)

if [[ $exists == *"true"* ]]; then
    # Bootnode registry exists - fetching current values
    log "Bootnode registry exists, fetching existing values from registry"
    response=$(az storage entity show -t $AZURE_STORAGE_TABLE --partition-key $AZURE_PARTITION_KEY --row-key $AZURE_ROW_KEY $table_args | grep -e "enode://" | awk '{ print $2 }')
    current_bootnodes=${response:1:-2}
    log "Existing bootnodes: $current_bootnodes"
else
    # Bootnode registry doesn't exist, something has failed
    log "Bootnode registry should have already been provisioned!"
    exit 1
fi

if [[ -z $current_bootnodes ]]; then
    # No existing bootnodes
    log "No existing bootnodes in registry"
    bootnode_args=""
else
    # Use existing bootnodes
    log "Using existing bootnodes from registry"
    bootnode_args="--bootnodes $current_bootnodes"
fi

# Setting Geth cmdline arguments
args="--datadir /opt/quorum/data $bootnode_args --networkid $GETHNETWORKID --rpc --rpcaddr 0.0.0.0 --rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,quorum --rpcport 8545 --port 30303"

# Inject Quorum role details if present
if [[ "${ISVOTER,,}" = 'true' ]];then
    log "Configuring client as voter"
    args="$args --voteaccount $VOTERACCOUNTADDRESS --votepassword \"${VOTERACCOUNTPASSWORD}\" "
fi
if [[ "${ISBLOCKMAKER,,}" = 'true' ]];then
    log "Configuring client as blockmaker"
    args="$args --blockmakeraccount $BLOCKMAKERACCOUNTADDRESS --blockmakerpassword \"${BLOCKMAKERACCOUNTPASSWORD}\" "
fi

# Start Geth
log "Starting Geth with args: $args"
PRIVATE_CONFIG=/opt/quorum/data/constellation.ipc
eval geth "${args}" 2>&1 > geth.log
if [[ $? -ne 0 ]]; then terminate !!