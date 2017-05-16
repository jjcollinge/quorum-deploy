#!/bin/bash

echo "///////////////////"
echo "Quorum Node Builder"
echo "///////////////////"

if [[ ! -d "keys" ]]; then
    mkdir -p source/geth/keys source/constellation/keys
fi

read OVERRIDE
while ([[ $OVERRIDE != "y" && $OVERRIDE != "n" ]]); do
    echo "$OVERRIDE is not a valid input, please try again."
    echo "Existing config files exists, are you sure you want to override? [y/n]"
    read OVERRIDE
done
if [[ $OVERRIDE == "n" ]]; then
    echo "Exiting"
    exit 1
fi
if [[ -d config/.temp ]]; then
    echo "Resetting config"
    cp config/.temp/* config/ && \
    mv config/env.sh.example config/env.sh && \
    mv config/genesis.json.example config/genesis.json && \
    mv config/gethbootstrap.sh.example config/gethbootstrap.sh && \
    mv config/node.conf.example config/node.conf
else
    echo "Unknown config state, this could be dangerous..."
fi

echo
echo "..............."
echo "Account details"
echo "..............."
echo

echo "Can this account vote? [y/n]"
read IS_VOTER
while ([[ $IS_VOTER != "y" && $IS_VOTER != "n" ]]); do
    echo "$IS_VOTER is not a valid input, please try again."
    echo "Can this account vote? [y/n]"
    read isVoter
done

echo "Can this account make blocks? [y/n]"
read IS_BLOCKMAKER
while ([[ $IS_BLOCKMAKER != "y" && $IS_BLOCKMAKER != "n" ]]); do
    echo "$IS_BLOCKMAKER is not a valid input, please try again."
    echo "Can this account make blocks? [y/n]"
    read isBlockmaker
done

echo "Please provide a passphrase to secure your account"
read PASSPHRASE
echo $PASSPHRASE >> .pp_tmp
geth --password .pp_tmp account new
rm .pp_tmp
GETH_KEY_FILE=$(geth account list | tail -n1 | awk '{print $4}')
GETH_ACCOUNT=$(geth account list | tail -n1 | awk '{print $3}')
GETH_ACCOUNT=${GETH_ACCOUNT:1:-1}
cp $GETH_KEY_FILE "keys/key"
constellation-enclave-keygen node
constellation-enclave-keygen nodea
mv node.* nodea.* "keys/"

if [[ $IS_VOTER == "y" && $IS_BLOCKMAKER == "y" ]]; then
    echo "Initialising account as voter and a block maker"
    echo "Creating secondary Geth account"
    echo "Please provide a passphrase to secure your secondary account"
    read SECONDARY_PASSPHRASE
    echo $SECONDARY_PASSPHRASE >> .pp_tmp
    geth --password .pp_tmp account new
    rm .pp_tmp
    SECONDARY_GETH_KEY_FILE=$(geth account list | tail -n1 | awk '{print $4}')
    SECONDARY_GETH_ACCOUNT=$(geth account list | tail -n1 | awk '{print $3}')
    SECONDARY_GETH_ACCOUNT=${SECONDARY_GETH_ACCOUNT:1:-1}
    cp $SECONDARY_GETH_KEY_FILE "keys/key1"
    sed -i -e "s/__GETH_ARGS__/--voteaccount \"0x$GETH_ACCOUNT\" --votepassword \"$PASSPHRASE\" --blockmakeraccount \"0x$SECONDARY_GETH_ACCOUNT\" --blockmakerpassword \"$SECONDARY_PASSPHRASE\"/g" config/gethbootstrap.sh
elif [[ $IS_VOTER == "y" ]]; then
    echo "Initialising account as voter"
    sed -i -e "s/__GETH_ARGS__/--voteaccount \"0x$GETH_ACCOUNT\" --votepassword \"$PASSPHRASE\"/g" config/gethbootstrap.sh
elif [[ $IS_BLOCKMAKER == "y" ]]; then
    echo "Initialising account as block maker"
    sed -i -e "s/__GETH_ARGS__/--blockmakeraccount \"0x$GETH_ACCOUNT\" --blockmakerpassword \"$PASSPHRASE\"/g" config/gethbootstrap.sh
fi

echo
echo "..............."
echo "Network details"
echo "..............."
echo

echo "Constellation URL (i.e. http://localhost:9000/): "
read CONSTELLATION_URL
echo "Constellation port: "
read OTHER_CONSTELLATION_URLS
echo "Is there an existing bootnode to connect to? [y/n]"
read BOOTNODE_EXISTS
while ([[ $BOOTNODE_EXISTS != "y" && $BOOTNODE_EXISTS != "n" ]]); do
    echo "$BOOTNODE_EXISTS is not a valid input, please try again."
    echo "Is there an existing bootnode to connect to? [y/n]"
    read BOOTNODE_EXISTS
done
if [[ $BOOTNODE_EXISTS == "y" ]]; then
    echo "Bootnode's public IP: "
    read BOOTNODE_IP
else
    echo "Configuring new bootnode"
    BOOTNODE_IP=""
fi
echo "Bootnode's port: "
read BOOTNODE_PORT
echo "Bootnode's hex key: "
read BOOTNODE_HEY_KEY
echo "Bootnode's public key: "
read BOOTNODE_PUBLIC_KEY
echo "RPC port: "
read RPC_PORT
echo "Geth port: "
read GETH_PORT
echo "Geth network id: "
read GETH_NETWORK_ID

sed -i -e "s/__BOOTNODE_IP__/$BOOTNODE_IP/g" config/env.sh
sed -i -e "s/__BOOTNODE_PORT__/$BOOTNODE_PORT/g" config/env.sh
sed -i -e "s/__BOOTNODE_HEX_KEY__/$BOOTNODE_HEY_KEY/g" config/env.sh
sed -i -e "s/__BOOTNODE_PUBLIC_KEY__/$BOOTNODE_PUBLIC_KEY/g" config/env.sh
sed -i -e "s/__RPC_PORT__/$RPC_PORT/g" config/env.sh
sed -i -e "s/__CONSTELLATION_PORT__/$CONSTELLATION_PORT/g" config/env.sh
sed -i -e "s/__GETH_PORT__/$GETH_PORT/g" config/env.sh
sed -i -e "s/__GETH_NETWORK_ID__/$GETH_NETWORK_ID/g" config/env.sh

sed -i -e "s@__CONSTELLATION_URL__@$CONSTELLATION_URL@g" config/node.conf
sed -i -e "s/__CONSTELLATION_PORT__/$CONSTELLATION_PORT/g" config/node.conf
IFS=',' read -r -a array <<< "$OTHER_CONSTELLATION_URLS"
STRINGIFIED=""
for URL in "${array[@]}"
do
    STRINGIFIED+="\"$URL\","
done
STRINGIFIED=${STRINGIFIED::-1}
sed -i -e "s@__OTHER_CONSTELLATION_URLS__@$STRINGIFIED@g" config/node.conf

echo
echo "..............."
echo "Finished script"
echo "..............."
echo