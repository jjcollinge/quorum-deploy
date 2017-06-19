#!/bin/bash
echo
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

mkdir -p "$NODE_DIR/geth"
mkdir -p "$NODE_DIR/constellation"

function askUserYesOrNoQuestion() {
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

function copyIfExists() {
    exists=$(docker exec "$containerId" test -f $1 && echo $?)
    if [[ $exists -eq 0 ]]; then
        docker cp "$containerId:$1" $2
    fi
}

# Determine if the node will be able to vote
isVoter=$(askUserYesOrNoQuestion "Will this account be able to vote?")
if [[ $isVoter == "y" ]]; then
    # Does an existing voter keyfile exist
    existingVoterKey=$(askUserYesOrNoQuestion "Do you have an existing key file for the voter?")
    if [[ $existingVoterKey == "y" ]]; then
        # Get the existing voter keyfile path from the user
        echo "Please enter a path to the key file"
        read voterKeyFile
        while ([ ! -f $voterKeyFile ]); do
            echo "Sorry, that file doesn't exist, please enter the correct path"
            read voterKeyFile
        done
        # Copy voter keyfile to node directory
        cp $voterKeyFile "$NODE_DIR/geth/key1"
        # Extract address from file
        VoterAddress=$(cat $voterKeyFile | awk -F ',' '{print $1}' | awk -F ':' '{print $2}')
        VoterAddress=${VoterAddress:1:-1}
    else
        # Get a passphrase to secure the generated keyfile
        echo "I'll generate a new key file, please give me a passphrase to secure the file"
        read VOTER_PASSPHRASE
    fi
fi

# Determine if the node will be able to make blocks
isBlockmaker=$(askUserYesOrNoQuestion "Will this account be able to make blocks?")
if [[ $isBlockmaker == "y" ]]; then
    # Does an existing blockmaker keyfile exist
    existingBlockmakerKey=$(askUserYesOrNoQuestion "Do you have an existing key file for the blockmaker?")
    if [[ $existingBlockmakerKey == "y" ]]; then
        # Get the existing blockmaker keyfile path from the user
        echo "Please enter a path to the key file"
        read blockmakerKeyFile
        while ([ ! -f $blockmakerKeyFile ]); do
            echo "Sorry, that file doesn't exist, please enter the correct path"
            read blockmakerKeyFile
        done
        # Copy blockmaker keyfile to node directory
        if [[ $existingVoterKey == "y" ]]; then
            # Voter key already in node directory
            cp $blockmakerKeyFile "$NODE_DIR/geth/key2"
        else
            cp $blockmakerKeyFile "$NODE_DIR/geth/key1"
        fi
        # Extract blockmaker address from keyfile
        BlockMakerAddress=$(cat $blockmakerKeyFile | awk -F ',' '{print $1}' | awk -F ':' '{print $2}')
        BlockMakerAddress=${BlockMakerAddress:1:-1}
    else
        # Get a passphrase to secure the generated keyfile
        echo "I'll generate a new key file, please give me a passphrase to secure the file"
        read BLOCKMAKER_PASSPHRASE
    fi
fi

# Determine whether constellation files already exist
existingConstellationKeys=$(askUserYesOrNoQuestion "Do you have existing constellation files?")
if [[ $existingConstellationKeys == "y" ]]; then
    # Copy constellation files to node directory
    echo "Please enter a path of all the existing constellation files (space delimited)"
    read constellationFiles
    cp $constellationFiles "$NODE_DIR/constellation"
else
    echo "Ok, I'll generate some default constellation files for you"
fi

if [[ $existingVoterKey == "n" || $existingBlockmakerKey == "n" || $existingConstellationKeys == "n" ]]; then
    echo "Generating your keys, please be paitent"
    # Start quorum container
    containerId=$(docker run -td agriessel/quorum)
    # Build bash command
    bashcmd=''
    if [[ $existingVoterKey == "n" ]]; then
        # Add voter key generation logic
        bashcmd='echo '"$VOTER_PASSPHRASE"' > voter.pw && \
                 geth --password voter.pw account new && \
                 voterkey=$(geth account list | tail -n1 | cut -d " " -f 4) && \
                 voteradd=$(geth account list | tail -n1 | cut -d " " -f 3) && \
                 voteradd=${voteradd:1:-1} && \
                 cp $voterkey key1 && \
                 echo "VOTER_ADD=$voteradd" > accounts '
    fi
    if [[ $existingBlockmakerKey == "n" ]]; then
        # Add blockmaker key generation logic
        if [[ -n "$bashcmd" ]]; then
            # Appending
            bashcmd="$bashcmd"' && \
                    echo '"$BLOCKMAKER_PASSPHRASE"' > blockmaker.pw && \
                    geth --password blockmaker.pw account new && \
                    blockmakerkey=$(geth account list | tail -n1 | cut -d " " -f 4) && \
                    blockmakeradd=$(geth account list | tail -n1 | cut -d " " -f 3) && \
                    blockmakeradd=${blockmakeradd:1:-1} && \
                    cp $blockmakerkey key2 && \
                    echo "BLOCKMAKER_ADD=$blockmakeradd" >> accounts '
        else
            # Starting
            bashcmd='echo '"$BLOCKMAKER_PASSPHRASE"' > blockmaker.pw && \
                    geth --password blockmaker.pw account new && \
                    blockmakerkey=$(geth account list | tail -n1 | cut -d " " -f 4) && \
                    blockmakeradd=$(geth account list | tail -n1 | cut -d " " -f 3) && \
                    blockmakeradd=${blockmakeradd:1:-1} && \
                    cp $blockmakerkey key1 && \
                    echo "BLOCKMAKER_ADD=$blockmakeradd" >> accounts '
        fi
    fi
    if [[ $existingConstellationKeys == "n" ]]; then
        if [[ -n "$bashcmd" ]]; then
            # Appending
            bashcmd="$bashcmd"' && \
                    yes "" | constellation-enclave-keygen node > /dev/null 2>&1 && \
                    yes "" | constellation-enclave-keygen nodea > /dev/null 2>&1 '
        else
            # Starting
            bashcmd='yes "" | constellation-enclave-keygen node > /dev/null 2>&1 && \
                     yes "" | constellation-enclave-keygen nodea > /dev/null 2>&1 '
        fi
    fi
    docker exec "$containerId" bash -c "$bashcmd" 2>&1 > /dev/null
    copyIfExists key1 "$NODE_DIR/geth"
    copyIfExists key2 "$NODE_DIR/geth"
    copyIfExists node.pub "$NODE_DIR/constellation"
    copyIfExists node.key "$NODE_DIR/constellation"
    copyIfExists nodea.pub "$NODE_DIR/constellation"
    copyIfExists nodea.key "$NODE_DIR/constellation"
    copyIfExists accounts .
    source accounts
    VoterAddress=$VOTER_ADD
    BlockMakerAddress=$BLOCKMAKER_ADD
    rm accounts
fi

# Get values for config file
if [[ $isVoter == "y" ]]; then
    IsVoterValue=true
else
    IsVoterValue=false
fi

if [[ $isBlockmaker == "y" ]]; then
    IsBlockMakerValue=true
else
    IsBlockMakerValue=false
fi

echo "Generating your deployment config"
echo '{
        "IsVoter": '"$IsVoterValue"',
        "VoterAccountAddress": "'"0x$VoterAddress"'",
        "IsBlockMaker": '"$IsBlockMakerValue"',
        "BlockMakerAccountAddress": "'"0x$BlockMakerAddress"'",
        "GethNetworkId": 4444,
        "AzureSubscriptionId": "",
        "AzureTenant": "",
        "AzureSPNAppId": "",
        "AzureSPNPassword": ""
     }' > "$NODE_DIR/config.json"

echo "Done config, let's start on the genesis.json"
existingGenesisFile=$(askUserYesOrNoQuestion "Do you have an existing genesis file?")
if [[ $existingGenesisFile == "y" ]]; then
    echo "Please enter the path to the genesis file"
    read genesisFile
    while ([ ! -f $genesisFile ]); do
        echo "Sorry, that file doesn't exist, please enter the correct path"
        read genesisFile
    done
    cp $genesisFile "$NODE_DIR/geth/genesis.json"
else
    buildGenesis=$(askUserYesOrNoQuestion "Would you like to build a new genesis.json file?")
    if [[ $buildGenesis == "y" ]]; then
        toolsInstalled=$(npm list -g | grep quorum-genesis)
        if [[ -z $toolsInstalled ]]; then
            echo "Tools not installed, hang tight whilst I go get them"
            git clone --quiet https://github.com/davebryson/quorum-genesis &> /dev/null
            npm install -g quorum-genesis 2>&1 > /dev/null
            rm -rf quorum-genesis
        fi
        echo "I've added your addresses to the genesis config, let's add any other members"
        voters=()
        if [[ $isVoter == "y" ]]; then
            voters+=("0x$VoterAddress")
        fi
        anotherVoter=$(askUserYesOrNoQuestion "Do you want to add more voters to the config?")
        while ([[ $anotherVoter == "y" ]]); do
            echo "Enter voter address (with 0x prefix):"
            read v
            voters+=("$v")
            anotherVoter=$(askUserYesOrNoQuestion "Do you want to add more voters to the config?")
        done
        blockmakers=()
        if [[ $isBlockmaker == "y" ]]; then
            blockmakers+=("0x$BlockMakerAddress")
        fi
        anotherBlockMaker=$(askUserYesOrNoQuestion "Do you want to add more blockmakers to the config?")
        while ([[ $anotherBlockMaker == "y" ]]); do
            echo "Enter blockmaker address (with 0x prefix):"
            read b
            blockmakers+=("$b")
            anotherBlockMaker=$(askUserYesOrNoQuestion "Do you want to add more blockmakers to the config?")
        done
        config='{"threshold":'"${#voters[@]}"',"voters":['
        for index in ${!voters[@]}; do
            config="$config\"${voters[index]}\","
        done
        config="${config::-1}],\"makers\":["
        for index in ${!blockmakers[@]}; do
            config="$config\"${blockmakers[index]}\","
        done
        config="${config::-1}]}"
        echo $config > "quorum-config.json"
        quorum-genesis
        cp quorum-genesis.json "$NODE_DIR/genesis.json"
        rm quorum-genesis.json
        rm quorum-config.json
    fi
    echo "Ok, well make sure to get a genesis.json file and put it in $NODE_DIR yourself"
fi

echo
echo "Your node files are in $NODE_DIR"
echo
echo "ATTENTION: You must fill in the missing values in the config.json file"
echo
echo "........................................."
echo
echo "This script uses these awesome project;"
echo "https://github.com/davebryson/quorum-genesis by Dave Bryson, thanks Dave!"
echo "https://github.com/agriessel/quorum-docker by Alex OpenSource, thanks Alex!"
echo