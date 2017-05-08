#!/bin/bash

NODE_ROOT="$PWD/quorum-node"
TEMP_PATH="$NODE_ROOT/temp"
export DATA_PATH="$TEMP_PATH/data"
CONFIG_PATH="$NODE_ROOT/config"
KEYS_PATH="$NODE_ROOT/keys"
SCRIPT_LOG="$TEMP_PATH/logs/script.log"
BOOTNODE_LOG="$TEMP_PATH/logs/bootnode.log"
CONSTELLATION_LOG="$TEMP_PATH/logs/constellation.log"
export GETH_LOG="$TEMP_PATH/logs/geth.log"

mkdir -p $KEYS_PATH
mkdir -p $TEMP_PATH/logs
touch $SCRIPT_LOG $BOOTNODE_LOG $CONSTELLATION_LOG $GETH_LOG

echo "Creating new Geth account" >>$SCRIPT_LOG
geth account new
GETH_KEY_FILE=$(geth account list | tail -n1 | awk '{print $4}')
cp $GETH_KEY_FILE "$KEYS_PATH/key"

echo "Creating new Constellation keys" >>$SCRIPT_LOG
constellation-enclave-keygen node
constellation-enclave-keygen nodea
mv node.* nodea.* $KEYS_PATH

# Source enviroment file
. $CONFIG_PATH/env.sh
echo "---------------" >>$SCRIPT_LOG
printenv >>$SCRIPT_LOG
echo "---------------" >>$SCRIPT_LOG

# Configure the node by moving files to the correct directories
echo "Configuring node" >>$SCRIPT_LOG
mkdir -p $DATA_PATH/keystore
stat -t -- $KEYS_PATH/key* >/dev/null 2>&1 && cp $KEYS_PATH/key* $DATA_PATH/keystore
sleep 2

# Initialise geth directory
geth --datadir $DATA_PATH init "$CONFIG_PATH/genesis.json"

sleep 10

# If no existing bootnode ip provided, start a local bootnode
if [ -z "$BOOTNODE_IP" ];
then
    echo "Starting bootnode" >>$SCRIPT_LOG
    BOOTNODE_IP="127.0.0.1"
    nohup bootnode --nodekeyhex "$BOOTNODE_KEYHEX" --addr="$BOOTNODE_IP:$BOOTNODE_PORT" 2>>$BOOTNODE_LOG &
    sleep 6
fi

# Start local constellation
echo "Starting constellation" >>$SCRIPT_LOG
nohup constellation-node "$CONFIG_PATH/node.conf" 2>>$CONSTELLATION_LOG &

sleep 10
# Set geth arguments
export BOOTNODE_ENODE="enode://$BOOTNODE_PUBLICKEY@[$BOOTNODE_IP]:$BOOTNODE_PORT" # Must exported to be used in gethbootstrap.sh

# Start geth
echo "Starting geth" >>$SCRIPT_LOG
"$CONFIG_PATH/gethbootstrap.sh" 2>>$GETH_LOG &

# Keep container alive forever
tail -f /dev/null






