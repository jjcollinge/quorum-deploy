#!/bin/bash

export NODE_ROOT="/quorum-node"
export TEMP_PATH="$NODE_ROOT/temp"
export DATA_PATH="$TEMP_PATH/data"
export CONFIG_PATH="$NODE_ROOT/config"
export KEYS_PATH="$NODE_ROOT/keys"
export SCRIPT_LOG="$TEMP_PATH/logs/script.log"
export BOOTNODE_LOG="$TEMP_PATH/logs/bootnode.log"
export CONSTELLATION_LOG="$TEMP_PATH/logs/constellation.log"
export GETH_LOG="$TEMP_PATH/logs/geth.log"

mkdir -p $TEMP_PATH/logs
touch $SCRIPT_LOG $BOOTNODE_LOG $CONSTELLATION_LOG $GETH_LOG

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

cp "$CONFIG_PATH/node.conf" .

# Start local constellation
echo "Starting constellation" >>$SCRIPT_LOG
nohup constellation-node node.conf 2>>$CONSTELLATION_LOG &

sleep 10
# Set geth arguments
export BOOTNODE_ENODE="enode://$BOOTNODE_PUBLICKEY@[$BOOTNODE_IP]:$BOOTNODE_PORT" # Must exported to be used in gethbootstrap.sh

# Start geth
echo "Starting geth" >>$SCRIPT_LOG
"$CONFIG_PATH/gethbootstrap.sh" 2>>$GETH_LOG &

# Keep container alive forever
tail -f /dev/null






