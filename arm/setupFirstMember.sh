#!/bin/bash

while getopts ":a:b:c:d:e:f:g:h:i:j:k:l:m" opt; do
  case "$opt" in
    a) IsVoter="$OPTARG"
    ;;
    b) VoterAccountAddress="$OPTARG"
    ;;
    c) VoterAccountPassword="$OPTARG"
    ;;
    d) IsBlockmaker="$OPTARG"
    ;;
    e) BlockmakerAccountAddress="$OPTARG"
    ;;
    f) BlockmakerAccountPassword="$OPTARG"
    ;;
    g) GethNetworkId="$OPTARG"
    ;;
    h) AzureStorageConnectionString="$OPTARG"
    ;;
    i) AzureTenant="$OPTARG"
    ;;
    j) AzureSPNAppId="$OPTARG"
    ;;
    k) AzureSPNPassword="$OPTARG"
    ;;
    l) ContainerHostIp="$OPTARG"
    ;;
    m) OtherConstellationNodes="$OPTARG"
    ;;
    n) OptionalDockerComposeArguments="$OPTARG"
  esac
done

cd /opt
git clone https://github.com/jjcollinge/quorum-node --branch feature/registry
cd quorum-node/source/

# Inject geth config
sed -i -e 's/__IsVoter__/'"$IsVoter"'/g' geth/config.json
sed -i -e 's/__VoterAccountAddress__/'"$VoterAccountAddress"'/g' geth/config.json
sed -i -e 's/__VoterAccountPassword__/'"$VoterAccountPassword"'/g' geth/config.json
sed -i -e 's/__IsBlockmaker__/'"$IsBlockmaker"'/g' geth/config.json
sed -i -e 's/__BlockmakerAccountAddress__/'"$BlockmakerAccountAddress"'/g' geth/config.json
sed -i -e 's/__BlockmakerAccountPassword__/'"$BlockmakerAccountPassword"'/g' geth/config.json
sed -i -e 's/__GethNetworkId__/'"$GethNetworkId"'/g' geth/config.json
sed -i -e 's@__AzureStorageConnectionString__@'"$AzureStorageConnectionString"'@g' geth/config.json
sed -i -e 's/__AzureTenant__/'"$AzureTenant"'/g' geth/config.json
sed -i -e 's/__AzureSPNAppId__/'"$AzureSPNAppId"'/g' geth/config.json
sed -i -e 's/__AzureSPNPassword__/'"$AzureSPNPassword"'/g' geth/config.json

# Inject bootnode config
sed -i -e 's/__ContainerHostIp__/'"$ContainerHostIp"'/g' bootnode/config.json
sed -i -e 's/__GethNetworkId__/'"$GethNetworkId"'/g' bootnode/config.json
sed -i -e 's@__AzureStorageConnectionString__@'"$AzureStorageConnectionString"'@g' bootnode/config.json
sed -i -e 's/__AzureTenant__/'"$AzureTenant"'/g' bootnode/config.json
sed -i -e 's/__AzureSPNAppId__/'"$AzureSPNAppId"'/g' bootnode/config.json
sed -i -e 's/__AzureSPNPassword__/'"$AzureSPNPassword"'/g' bootnode/config.json

# Inject constellation config
sed -i -e "s/__OtherConstellationNodes__//g" constellation/node.conf

# Inject cakeshop config
sed -i -e 's/__GethNetworkId__/'"$GethNetworkId"'/g' quorum-bootnode.yml

docker-compose -f quorum-bootnode.yml $OptionalDockerComposeArguments up -d