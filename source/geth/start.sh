#!/bin/bash

# Load config
echo "Loading configuration file"| tee temp/logs/start.log
rm -f /opt/quorum/env.sh
python /opt/quorum/loadconfig.py
source /opt/quorum/env.sh

# Define global constants
local_ip="0.0.0.0"
azure_storage_table="networkbootnodes"
azure_partition_key=1494663149
azure_row_key=$GETHNETWORKID
bootnode_port=33445
blob_container="node"
blob_file="files.zip"

if [[ -z $GETHNETWORKID ]]; then
    echo "Empty or invalid required config.json field: GethNetworkId"| tee temp/logs/start.log
    exit 1
fi
if [[ -z $AZURETENANT ]]; then
    echo "Empty or invalid required config.json field: AzureTenant"| tee temp/logs/start.log
    exit 1
fi
if [[ -z $AZURESPNAPPID ]]; then
    echo "Empty or invalid required config.json field: AzureSPNAppId"| tee temp/logs/start.log
    exit 1
fi
if [[ -z $AZURESPNPASSWORD ]]; then
    echo "Empty or invalid required config.json field: AzureSPNPassword"| tee temp/logs/start.log
    exit 1
fi
if [[ -z $AZURESUBSCRIPTIONID ]]; then
    echo "Empty or invalid required config.json field: AzureSubscriptionId"| tee temp/logs/start.log
    exit 1
fi
if [[ -z $AZURETABLESTORAGENAME ]]; then
    echo "Empty or invalid required config.json field: AzureTableStorageName"| tee temp/logs/start.log
    exit 1
fi
if [[ -z $AZURETABLESTORAGESAS ]]; then
    echo "Empty or invalid required config.json field: AzureTableStorageSas"| tee temp/logs/start.log
    exit 1
fi

# Login to Azure Storage with SPN
echo "Logging into Azure"| tee temp/logs/start.log
az login --service-principal -u $AZURESPNAPPID -p $AZURESPNPASSWORD --tenant $AZURETENANT | tee temp/logs/start.log
az account set -s $AZURESUBSCRIPTIONID | tee temp/logs/start.log

# Initialise Geth
echo "Initialising geth"| tee temp/logs/start.log
geth --datadir /opt/quorum/data init genesis.json

# Copy key files into keystore
echo "Copying key files to keystore"| tee temp/logs/start.log
for key in "keys/key*"; do
    cp $key /opt/quorum/data/keystore
done

# Check bootnode registry exists
echo "Checking whether bootnode registry '$azure_storage_table' exists"| tee temp/logs/start.log
table_args="--account-name $AZURETABLESTORAGENAME --sas-token $AZURETABLESTORAGESAS"
exists=$(az storage table exists --name $azure_storage_table $table_args)

if [[ $exists == *"true"* ]]; then
    # Fetch current value
    echo "Fetching existing bootnodes from registry"| tee temp/logs/start.log
    response=$(az storage entity show -t $azure_storage_table --partition-key $azure_partition_key --row-key $azure_row_key $table_args | grep -e "enode://" | awk '{ print $2 }')
    current_bootnodes=${response:1:-2}
    echo "Current bootnodes: $current_bootnodes"| tee temp/logs/start.log
fi

if [[ -z $current_bootnodes ]]; then
    # Don't use bootnodes
    echo "No existing bootnodes in registry"| tee temp/logs/start.log
    bootnode_args=""
else
    # Use bootnodes
    bootnode_args="--bootnodes $current_bootnodes"
fi

# Start Geth
args="--datadir /opt/quorum/data $bootnode_args --networkid $GETHNETWORKID --rpc --rpcaddr 0.0.0.0 --rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,quorum --rpcport 8545 --port 30303"

if [[ "${ISVOTER,,}" = 'true' ]];then
    args="$args --voteaccount $VOTERACCOUNTADDRESS --votepassword \"${VOTERACCOUNTPASSWORD}\" "
fi

if [[ "${ISBLOCKMAKER,,}" = 'true' ]];then
    args="$args --blockmakeraccount $BLOCKMAKERACCOUNTADDRESS --blockmakerpassword \"${BLOCKMAKERACCOUNTPASSWORD}\" "
fi

echo "Starting geth with args: $args"| tee temp/logs/start.log
PRIVATE_CONFIG=/opt/quorum/data/constellation.ipc
eval geth "${args}" 2>>temp/logs/geth.log