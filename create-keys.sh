#!/bin/bash
echo "///////////////////////////"
echo " Create Quorum Keys Script"
echo "///////////////////////////"
echo
echo "Ok let's begin"

geth_keys="source/geth/keys"
constellation_keys="source/constellation/keys"

if [[ ! -d $geth_keys || ! -d  $constellation_keys ]]; then
    echo "The geth or constellation key directories (source/geth/keys and source/constellation/keys) don't exist, please create them before retrying"
fi

function promptUser() {
    prompt=$1
    echo "$prompt [y/n]" >&2
    read response
    while ([[ $response != "y" && $response != "n" ]]); do
        echo "$response is not a valid input, please try again." >&2
        echo "$prompt [y/n]" >&2
        read response
    done
    echo $response
}

function createGethKeys() {
    echo "Please provide a passphrase to secure your account"
    read PASSPHRASE
    echo $PASSPHRASE >> .pp_tmp
    geth --password .pp_tmp account new
    rm .pp_tmp
    GETH_KEY_FILE=$(geth account list | tail -n1 | awk '{print $4}')
    cp $GETH_KEY_FILE "$geth_keys/key"
}

voter=$(promptUser "Will this account be able to vote?")
blockmaker=$(promptUser "Will this account be able to make blocks?")

# Create first account for single role
createGethKeys 1
if [[ $voter == "y" ]] && [[ $blockmaker == "y" ]]; then
    # Create second accout for two roles
    echo "Creating secondary role keys"
    createGethKeys 2
fi

# Create constellation keys with no password
yes "" | constellation-enclave-keygen node > /dev/null 2>&1
yes "" | constellation-enclave-keygen nodea > /dev/null 2>&1
mv node.* nodea.* $constellation_keys