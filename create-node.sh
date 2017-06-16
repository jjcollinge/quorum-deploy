#!/bin/bash
echo "///////////////////////////"
echo " Create Quorum Keys Script"
echo "///////////////////////////"
echo
echo "Ok let's begin"

if [[ -z $1 ]]; then
    echo "Usage: you must provide your output node directory as an argument."
    exit 1
fi

NODE_DIR=$1

if [[ ! -d $1 ]]; then
    echo "Your output key directory $NODE_DIR does not exist"
    exit 1
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

voter=$(promptUser "Will this account be able to vote?")
blockmaker=$(promptUser "Will this account be able to make blocks?")

echo "Please provide a passphrase to secure your account"
read PASSPHRASE
if [[ $voter == "y" ]] && [[ $blockmaker == "y" ]]; then
    echo "Please provide a passphrase to secure your secondary account"
    read SEC_PASSPHRASE
    twokeys=true
else
    twokeys=false
fi

containerId=$(docker run -td agriessel/quorum)

if [[ $twokeys == true ]]; then
    docker exec "$containerId" bash -c 'echo '"$PASSPHRASE"' > primary.pw && \
                                        echo '"$SEC_PASSPHRASE"' > secondary.pw && \
                                        geth --password primary.pw account new && \
                                        primarykey=$(geth account list | tail -n1 | cut -d " " -f 4) && \
                                        primaryadd=$(geth account list | tail -n1 | cut -d " " -f 3) && \
                                        primaryadd=${primaryadd:1:-1} && \
                                        geth --password secondary.pw account new && \
                                        secondarykey=$(geth account list | tail -n1 | cut -d " " -f 4) && \
                                        secondaryadd=$(geth account list | tail -n1 | cut -d " " -f 3) && \
                                        secondaryadd=${secondaryadd:1:-1} && \
                                        cp $primarykey key1 && \
                                        cp $secondarykey key2 && \
                                        yes "" | constellation-enclave-keygen node > /dev/null 2>&1 && \
                                        yes "" | constellation-enclave-keygen nodea > /dev/null 2>&1 && \
                                        echo "PRI_ADD=$primaryadd" > accounts && \
                                        echo "SEC_ADD=$secondaryadd" >> accounts'
    docker cp "$containerId":key1 $NODE_DIR
    docker cp "$containerId":key2 $NODE_DIR
    docker cp "$containerId":node.pub $NODE_DIR
    docker cp "$containerId":node.key $NODE_DIR
    docker cp "$containerId":nodea.pub $NODE_DIR
    docker cp "$containerId":nodea.key $NODE_DIR
    docker cp "$containerId":accounts .
else
    docker exec $containerId bash -c 'echo '"$PASSPHRASE"' > primary.pw && \
                                        geth --password primary.pw account new && \
                                        primarykey=$(geth account list | tail -n1 | cut -d " " -f 4) && \
                                        primaryadd=$(geth account list | tail -n1 | cut -d " " -f 3) && \
                                        primaryadd=${primaryadd:1:-1} && \
                                        cp $primarykey key1 && \
                                        yes "" | constellation-enclave-keygen node > /dev/null 2>&1 && \
                                        echo "PRI_ADD=$primaryadd" > accounts'
    docker cp "$containerId":key1 "$NODE_DIR"
    docker cp "$containerId":node.pub $NODE_DIR
    docker cp "$containerId":node.key $NODE_DIR
    docker cp "$containerId":accounts .
fi

source accounts

if [[ $voter == "y" ]]; then
    IsVoter=true
    VoterAddress=$PRI_ADD
else
    IsVoter=false
fi

if [[ $blockmaker == "y" ]]; then
    IsBlockMaker=true
    if [[ -z $VoterAddress ]]; then
        BlockMakerAddress=$PRI_ADD
    else
        BlockMakerAddress=$SEC_ADD
    fi
else
    IsBlockMaker=false
fi

echo '{
        "IsVoter": '"$IsVoter"',
        "VoterAccountAddress": '"$VoterAddress"',
        "IsBlockMaker": '"$IsBlockMaker"',
        "BlockMakerAccountAddress": '"$BlockMakerAddress"',
        "GethNetworkId": 4444,
        "AzureSubscriptionId": "",
        "AzureTenant": "",
        "AzureSPNAppId": "",
        "AzureSPNPassword": ""
     }' > "$NODE_DIR/config.json"

rm accounts