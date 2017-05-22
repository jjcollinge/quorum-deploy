#!/bin/bash

# Start local bootnode
nohup bootnode -genkey bootnode.key -addr "0.0.0.0:33445" 2>>/temp/logs/bootnode.log &

# Load config
echo "Loading configuration file">>start.log
rm -f /opt/bootnode/env.sh
python /opt/bootnode/loadconfig.py
source /opt/bootnode/env.sh

# Define global constants
azure_storage_table="networkbootnodes"
azure_partition_key=1494663149
azure_row_key=$GETHNETWORKID
external_port=33445

CONTAINERHOSTIP=$(curl -s -4 http://checkip.amazonaws.com || printf "0.0.0.0")

# Check required enviroment variables
if [[ -z $CONTAINERHOSTIP ]]; then
    echo "Empty or invalid required config.json field: ContainerHostIp"
    exit 1
fi
if [[ -z $AZURESTORAGECONNECTIONSTRING ]]; then
    echo "Empty or invalid required config.json field: AzureStorageConnectionString"
    exit 1
fi
if [[ -z $GETHNETWORKID ]]; then
    echo "Empty or invalid required config.json field: GethNetworkId"
    exit 1
fi
if [[ -z $AZURETENANT ]]; then
    echo "Empty or invalid required config.json field: AzureTenant"
    exit 1
fi
if [[ -z $AZURESPNAPPID ]]; then
    echo "Empty or invalid required config.json field: AzureSPNAppId"
    exit 1
fi
if [[ -z $AZURESPNPASSWORD ]]; then
    echo "Empty or invalid required config.json field: AzureSPNPassword"
    exit 1
fi
export AZURE_STORAGE_CONNECTION_STRING=$AZURESTORAGECONNECTIONSTRING

echo "Configuring bootnode">>start.log

# Grab the bootnode public key
local_bootnode=$(grep -i "listening" bootnode.log | awk '{print $5}')

# Register bootnode with table storage
echo "Checking whether bootnode registry '$azure_storage_table' exists">>/temp/logs/start.log
exists=$(az storage table exists --name $azure_storage_table)

if [[ $exists == *"false"* ]]; then
    # Create table if it doesn't exist
    echo "No existing registry, creating '$azure_storage_table">>/temp/logs/start.log
    az storage table create --name $azure_storage_table >>/temp/logs/azure.log
fi

# Fetch current value
echo "Getting existing bootnodes">>start.log
response=$(az storage entity show -t $azure_storage_table --partition-key $azure_partition_key --row-key $azure_row_key | grep -e "enode://" | awk '{ print $2 }')
current_bootnodes=${response:1:-2}

# Update the values to include the local bootnode
bootnode_enode="${local_bootnode/::/$CONTAINERHOSTIP}"
internal_port=$(echo "$bootnode_enode" | awk -F: '{print $3}')
bootnode_enode="${bootnode_enode/$internal_port/$external_port}"

if [[ -z $current_bootnodes ]]; then
    current_bootnodes=$bootnode_enode
    echo "Registry is empty, initialising it with $current_bootnodes">>/temp/logs/start.log
    az storage entity insert -t $azure_storage_table -e PartitionKey=$azure_partition_key RowKey=$azure_row_key Content=$current_bootnodes >>/temp/logs/azure.log
else
    current_bootnodes="$current_bootnodes,$bootnode_enode"
    echo "Updating bootnode registry with $current_bootnodes">>/temp/logs/start.log
    az storage entity replace -t $azure_storage_table -e PartitionKey=$azure_partition_key RowKey=$azure_row_key Content=$current_bootnodes >>/temp/logs/azure.log
fi

# Keep container alive
echo "Sleeping indefinitely">>/temp/logs/start.log
tail -f /dev/null