#!/bin/bash
echo "///////////////////////////"
echo " Create Quorum Keys Script"
echo "///////////////////////////"
echo
echo "Ok let's begin"

if [[ -z $1 ]]; then
    echo "Please provide the location of your key folder"
    exit 1
fi

keydir=$1

if [[ ! -d $keydir ]]; then
    echo "The key directory $keydir doesn't exists, I'll create it now"
    mkdir -p $keydir
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
    cp $GETH_KEY_FILE "$keydir/key$1"
}

voter=$(promptUser "Will this account be able to vote?")
blockmaker=$(promptUser "Will this account be able to make blocks?")

# Create first account for single role
createGethKeys 1
if [[ voter == "y" ]] && [[ blockmaker == "y" ]]; then
    # Create second accout for two roles
    createGethKeys 2
fi

# Create constellation keys with no password
yes "" | constellation-enclave-keygen node > /dev/null 2>&1
yes "" | constellation-enclave-keygen nodea > /dev/null 2>&1
mv node.* nodea.* "$keydir"

echo "Keys created, they're stored in $keydir"