#!/bin/bash

# Define paths
root=$(pwd)
temp_path="$root/temp"
data_path="$root/data"
key_path="$root/keys"
src_path="$root/src"
log_path="$temp_path/logs"
keystore_path="$data_path/keystore"
bootnode_keyfile_path="$root/bootnode"

# Load config
echo "Loading configuration file">>"$log_path/start.log"
rm -f "$src_path/env.sh"
python "$src_path/loadconfig.py"
source "$src_path/env.sh"

# Define global constants
local_ip="0.0.0.0"
azure_storage_table="networkbootnodes"
azure_partition_key=1494663149
azure_row_key=$GETHNETWORKID
bootnode_port=33445

# Check required enviroment variables
if [[ -z $PUBLICBOOTNODEIP ]]; then
    echo "Empty or invalid required config.json field: PublicBootnodeIP"
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
if [[ -z $PUBLICBOOTNODEPORT ]]; then
    # Default bootnode port
    PUBLICBOOTNODEPORT=$bootnode_port
fi
export AZURE_STORAGE_CONNECTION_STRING=$AZURESTORAGECONNECTIONSTRING

# Login to Azure Storage with SPN
echo "Logging into Azure">>"$log_path/start.log"
az login --service-principal -u $AZURESPNAPPID -p $AZURESPNPASSWORD --tenant $AZURETENANT >>"$log_path/azure.log"

# Copy key files into keystore
echo "Moving key files">>"$log_path/start.log"
for key in "$key_path/key*"; do
    cp $key $keystore_path
done

# Initialise Geth
echo "Initialising geth">>"$log_path/start.log"
geth --datadir $data_path init "$src_path/genesis.json"

# Start a local bootnode if required
if [[ "${ENABLEBOOTNODE,,}" = 'true' ]]; then
    echo "Configuring bootnode">>"$log_path/start.log"
    # Create key file if it doesn't exist
    if [[ ! -f "$bootnode_keyfile_path/bootnode.key" ]]; then
        echo "No existing bootnode key, generating one">>"$log_path/start.log"
        mkdir -p $bootnode_keyfile_path
        #bootnode -genkey "$bootnode_keyfile_path/bootnode.key" >>$log_path/bootnode.log
        bootnode_args="-genkey $bootnode_keyfile_path/bootnode.key --addr $local_ip:$bootnode_port"
    else
        bootnode_args="--nodekey $bootnode_keyfile_path/bootnode.key --addr $local_ip:$bootnode_port"
    fi
    echo "Starting bootnode with args: $bootnode_args">>"$log_path/start.log"
    nohup bootnode $bootnode_args >>$log_path/bootnode.log &
    sleep 4
    # Grab the bootnode public key
    local_bootnode=$(grep -i "listening" temp/logs/bootnode.log | awk '{print $5}')
    # Register bootnode with table storage
    echo "Checking whether bootnode registry '$azure_storage_table' exists">>"$log_path/start.log"
    exists=$(az storage table exists --name $azure_storage_table)
    if [[ $exists == *"false"* ]]; then
        # Create table if it doesn't exist
        echo "No existing registry, creating '$azure_storage_table">>"$log_path/start.log"
        az storage table create --name $azure_storage_table >>"$log_path/azure.log"
    fi
    # Fetch current value
    echo "Getting existing bootnodes">>"$log_path/start.log"
    response=$(az storage entity show -t $azure_storage_table --partition-key $azure_partition_key --row-key $azure_row_key | grep -e "enode://" | awk '{ print $2 }')
    current_bootnodes=${response:1:-2}
    # Update the values to include the local bootnode
    bootnode_enode="${local_bootnode/::/$PUBLICBOOTNODEIP}"
    internal_port=$(echo "$bootnode_enode" | awk -F: '{print $3}')
    bootnode_enode="${bootnode_enode/$internal_port/$PUBLICBOOTNODEPORT}"
    if [[ -z $current_bootnodes ]]; then
        current_bootnodes=$bootnode_enode
        echo "Registry is empty, initialising it with $current_bootnodes">>"$log_path/start.log"
        az storage entity insert -t $azure_storage_table -e PartitionKey=$azure_partition_key RowKey=$azure_row_key Content=$current_bootnodes >>"$log_path/azure.log"
    else
        current_bootnodes="$current_bootnodes,$bootnode_enode"
        echo "Updating bootnode registry with $current_bootnodes">>"$log_path/start.log"
        az storage entity replace -t $azure_storage_table -e PartitionKey=$azure_partition_key RowKey=$azure_row_key Content=$current_bootnodes >>"$log_path/azure.log"
    fi
    # Assume this is first node so clear node.conf 'OtherNodeUrls' field
    echo "Updating constellation configuration" >>"$log_path/start.log"
    sed -i -e 's/__OTHER_NODE_URLS__//g' "$src_path/node.conf"
else
    # Fetch current value
    echo "Fetching existing bootnodes from registry">>"$log_path/start.log"
    response=$(az storage entity show -t $azure_storage_table --partition-key $azure_partition_key --row-key $azure_row_key | grep -e "enode://" | awk '{ print $2 }')
    current_bootnodes=${response:1:-2}
    if [[ -z $current_bootnodes ]]; then
        echo "There are not existing bootnodes to connect to">>"$log_path/start.log"
    else
        # Add bootnode IP as constellation node
        regex="(?:enode://)([^:/ ]+)@?([0-9]*):?([0-9]*)*"
        echo "Updating constellation conf">>"$log_path/start.log"
        if [[ $current_bootnodes =~ $regex ]]; then
            host_ip="${BASH_REMATCH[2]}"
            echo "Matched with host $host_ip">>"$log_path/start.log"
            sed -i -e "s/__OTHER_NODE_URLS__/\"$host_ip:9000\"/g" "$src_path/node.conf"
        else
            echo "Couldn't match with any hosts from current bootnodes: $current_bootnodes">>"$log_path/start.log"
        fi
    fi
fi

# Start local constellation
echo "Starting constellation">>"$log_path/start.log"
cp "$src_path/node.conf" $root
nohup constellation-node "$root/node.conf" >> "$log_path/constellation.log" &

# Allow constellation time to come up
echo "Waiting for constellation to start">>"$log_path/start.log"
sleep 10

# Start Geth
args="--datadir $data_path --bootnodes $current_bootnodes --networkid $GETHNETWORKID --rpc --rpcaddr 0.0.0.0 --rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,quorum --rpcport 8545 --port 30303"
if [[ "${ISVOTER,,}" = 'true' ]];then
    args="$args --voteaccount $VOTERACCOUNTADDRESS --votepassword \"${VOTERACCOUNTPASSWORD}\" "
fi

if [[ "${ISBLOCKMAKER,,}" = 'true' ]];then
    args="$args --blockmakeraccount $BLOCKMAKERACCOUNTADDRESS --blockmakerpassword \"${BLOCKMAKERACCOUNTPASSWORD}\" "
fi
echo "Starting geth with args: $args">>"$log_path/start.log"
eval nohup geth "${args}" >>"$log_path/geth.log" &

# Keep container alive
echo "Sleeping indefinitely">>"$log_path/start.log"
tail -f /dev/null