#!/bin/bash

while getopts ":a:b:c:d:e:f:g:h:i:j:k:l:m" opt; do
  case $opt in
    a) isVoter="$OPTARG"
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
  esac
done

cd /opt
git clone https://github.com/jjcollinge/quorum-node --branch feature/registry
cd quorum-node/source/

# Inject geth config
sed -i -e 's/${IsVoter}/$IsVoter/g' geth/config.json
sed -i -e 's/${VoterAccountAddress}/$VoterAccountAddress/g' geth/config.json
sed -i -e 's/${VoterAccountPassword}/$VoterAccountPassword/g' geth/config.json
sed -i -e 's/${IsBlockmaker}/$isBlockmaker/g' geth/config.json
sed -i -e 's/${BlockmakerAccountAddress}/$BlockmakerAccountAddress/g' geth/config.json
sed -i -e 's/${BlockmakerAccountPassword}/$BlockmakerAccountPassword/g' geth/config.json
sed -i -e 's/${GethNetworkId}/$GethNetworkId/g' geth/config.json
sed -i -e 's/${AzureStorageConnectionString}/$AzureStorageConnectionString/g' geth/config.json
sed -i -e 's/${AzureTenant}/$AzureTenant/g' geth/config.json
sed -i -e 's/${AzureSPNAppId}/$AzureSPNAppId/g' geth/config.json
sed -i -e 's/${AzureSPNPassword}/$AzureSPNPassword/g' geth/config.json

# Inject bootnode config
sed -i -e 's/${ContainerHostIp}/$ContainerHostIp/g' bootnode/config.json
sed -i -e 's/${GethNetworkId}/$GethNetworkId/g' bootnode/config.json
sed -i -e 's/${AzureStorageConnectionString}/$AzureStorageConnectionString/g' bootnode/config.json
sed -i -e 's/${AzureTenant}/$AzureTenant/g' bootnode/config.json
sed -i -e 's/${AzureSPNAppId}/$AzureSPNAppId/g' bootnode/config.json

# Inject constellation config
sed -i -e 's/${OtherConstellationNodes}//g' constellation/node.conf

# Inject cakeshop config
sed -i -e 's/${GethNetworkId}/$GethNetworkId/g' quorum-bootnode.yml

docker-compose -f quorum-bootnode.yml up -d