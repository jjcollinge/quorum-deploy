# Quorum Deploy

## Description
Quorum-deploy aims to provide a simple way to stand up a consortium quorum network on the Azure cloud platform.

## Requirements

* linux
* docker
* [azure CLI 2.0](https://docs.microsoft.com/en-gb/cli/azure/install-azure-cli)
* node and npm
* azure subscription (with owner permissions)

## Disclaimer
This project is work-in-progress and is dependent on a number of immature and untested technologies. At any point in time the build may be broken, not working properly or incomplete. Please only use this project as a reference or for your own experimentation.

## Installation
Other than the above requirements, there is no installation process for quorum-deploy. Just clone this repo to your local machine and follow the instructions in the *Usage* section of this document.

## Prerequiste
The templates requires an Azure Service Principal registered with owner permissions in the Azure subscription you intend to use. For documentation on how to do this, please use [this link](https://github.com/Azure/azure-docs-cli-python/blob/master/docs-ref-conceptual/create-an-azure-service-principal-azure-cli.md)

## Usage (Example node)

1. Open and complete the empty fields in the configuration files to work with your own Azure subscription

* ./arm/firstMember.parameters.json
* ./example-node/config.json

2. Run the deploy node script and target the example-node configuration

```
    ./deploy-node.sh -n myrg -l westeurope -t ./arm/firstMember.json -p firstMember.parameters.json -d ./example-node
```
 
3. Grab your deployments public ip address and go explore your deployment

4. Your geth client should now be connected. Grab your IP or DNS name from the deployment outputs or the Azure portal and visit your cakeshop portal at http://{fqdn}.com:8080/cakeshop

## Usage (Custom node)

1. The first thing to do is setup your nodes quorum configuration. Do this by creating a new folder `mkdir -p node` in the root of the repo.

2. Next, run the create node script passing in your node directory as an argument. Follow the on screen instructions to configure your node and network.

```
    ./create-node.sh node/
```

3. Go add your Azure subscription details to the `config.json` file

4. Review your ARM template parameters (i.e. arm/firstMember.parameters.json).

5. Run the deployment script with the required arguments to kick of your Azure deployment.

```
    ./deploy-node.sh

    usage:  [-n resourcegroup ] [-l location ] [-t templatefile ] [-p parameterfile ] [-d node ]
  -n resourcegroup     specify an azure resource group
  -l location     specify an azure location
  -t templatefile     specify an arm template file
  -p parameterfile     specify an arm parameters file
  -d node     specify a local node directory
```
6. Your geth client should now be connected. Grab your IP or DNS name from the deployment outputs or the Azure portal and visit your cakeshop portal at http://{fqdn}.com:8080/cakeshop


