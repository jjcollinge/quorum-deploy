# quorum-deploy

## Description
Quorum-deploy aims to provide a simple way to stand up a consortium quorum network on the Azure cloud platform.

## Requirements

* Linux
* Docker
* [Azure CLI 2.0](https://docs.microsoft.com/en-gb/cli/azure/install-azure-cli)
* Azure subscription (with owner permissions)

## Installation
Other than the above requirements, there is no installation process for quorum-deploy. Just clone this repos to your local machine and follow the instructions in the *Usage* section of this document.

## Usage

1. The first thing to do is setup your nodes quorum configuration. Do this by creating a new folder `mkdir -p node` in the root of the repo.

2. Next, run the create node script passing in your node directory as an argument. Follow the on screen instructions to configure your node and network.

```
    ./create-node.sh node/
```

3. Run the deployment script with the required arguments to kick of your Azure deployment.

```
    ./deploy.sh

    usage:  [-n resourcegroup ] [-l location ] [-t templatefile ] [-p parameterfile ] [-d node ]
  -n resourcegroup     specify an azure resource group
  -l location     specify an azure location
  -t templatefile     specify an arm template file
  -p parameterfile     specify an arm parameters file
  -d node     specify a local node directory
```

