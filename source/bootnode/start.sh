#!/bin/bash

# Start local bootnode
nohup bootnode -genkey bootnode.key -addr "0.0.0.0:33445" 2>>logs/bootnode.log &

# Wait for bootnode to start listening
sleep 6

# Load config
echo "Loading configuration file">>logs/start.log
rm -f /opt/bootnode/env.sh
python /opt/bootnode/loadconfig.py
source /opt/bootnode/env.sh

# Define global constants
azure_storage_table="networkbootnodes"
azure_partition_key=1494663149
azure_row_key=$GETHNETWORKID
external_port=33445

CONTAINERHOSTIP=$(curl -s -4 http://checkip.amazonaws.com || printf "0.0.0.0")
echo "Configuring bootnode on $CONTAINERHOSTIP">>logs/start.log

# Check required enviroment variables
if [[ -z $CONTAINERHOSTIP ]]; then
    echo "Could not determine the host IP">>logs/start.log
    exit 1
fi
if [[ -z $GETHNETWORKID ]]; then
    echo "Empty or invalid required config.json field: GethNetworkId">>logs/start.log
    exit 1
fi
if [[ -z $AZURETENANT ]]; then
    echo "Empty or invalid required config.json field: AzureTenant">>logs/start.log
    exit 1
fi
if [[ -z $AZURESPNAPPID ]]; then
    echo "Empty or invalid required config.json field: AzureSPNAppId">>logs/start.log
    exit 1
fi
if [[ -z $AZURESPNPASSWORD ]]; then
    echo "Empty or invalid required config.json field: AzureSPNPassword">>logs/start.log
    exit 1
fi
if [[ -z $AZURETABLESTORAGENAME ]]; then
    echo "Empty or invalid required config.json field: AzureResourceGroup">>temp/logs/start.log
    exit 1
fi
if [[ -z $AZURETABLESTORAGESAS ]]; then
    echo "Empty or invalid required config.json field: AzureResourceGroup">>temp/logs/start.log
    exit 1
fi

# Login to Azure Storage with SPN
echo "Logging into Azure">>temp/logs/start.log
az login --service-principal -u $AZURESPNAPPID -p $AZURESPNPASSWORD --tenant $AZURETENANT >>temp/logs/azure.log

# Grab the bootnode public key
local_bootnode=$(grep -i "listening" logs/bootnode.log | awk '{print $5}' | head -n 1)

# Register bootnode with table storage
echo "Checking whether bootnode registry '$azure_storage_table' exists">>logs/start.log
table_args="--account-name $AZURETABLESTORAGENAME --sas-token $AZURETABLESASTOKEN"
exists=$(az storage table exists --name $azure_storage_table $table_args)

if [[ $exists == *"false"* ]]; then
    # Create table if it doesn't exist
    echo "No existing registry, creating '$azure_storage_table">>logs/start.log
    az storage table create --name $azure_storage_table $table_args>>logs/azure.log
fi

# Fetch current value
echo "Getting existing bootnodes">>logs/start.log
response=$(az storage entity show -t $azure_storage_table --partition-key $azure_partition_key --row-key $azure_row_key $table_args | grep -e "enode://" | awk '{ print $2 }')
current_bootnodes=${response:1:-2}

# Update the values to include the local bootnode
bootnode_enode="${local_bootnode/::/$CONTAINERHOSTIP}"
bootnode_enode="${bootnode_enode//[}"
bootnode_enode="${bootnode_enode//]}"
internal_port=$(echo "$bootnode_enode" | awk -F: '{print $3}')
bootnode_enode="${bootnode_enode/$internal_port/$external_port}"

if [[ -z $current_bootnodes ]]; then
    current_bootnodes=$bootnode_enode
    echo "Registry is empty, initialising it with $current_bootnodes">>logs/start.log
    az storage entity insert -t $azure_storage_table -e PartitionKey=$azure_partition_key RowKey=$azure_row_key Content=$current_bootnodes $table_args >>logs/azure.log
else
    current_bootnodes="$current_bootnodes,$bootnode_enode"
    echo "Updating bootnode registry with $current_bootnodes">>logs/start.log
    az storage entity replace -t $azure_storage_table -e PartitionKey=$azure_partition_key RowKey=$azure_row_key Content=$current_bootnodes $table_args >>logs/azure.log
fi

# Keep container alive
echo "Sleeping indefinitely">>logs/start.log
tail -f /dev/null