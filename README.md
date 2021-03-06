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

1. Open `./arm/firstMember.parameters.json`

2. Provide values for the following fields:
* `adminUsername`
* `adminPassword`
* `dnsLabelPrefix` (must be unique)

3. Save and close the file

4. Open `./example-node/config.json`

5. Provide values for the following fields:
* `AzureSubscriptionId`
* `AzureTenant`
* `AzureSPNAppId`
* `AzureSPNPassword`

6. Save and close the file

7. Run the deploy node script and target the example-node configuration

```
    ./deploy-node.sh -n myrg -l westeurope -t ./arm/firstMember.json -p ./arm/firstMember.parameters.json -d ./example-node
```
 
8. Grab your deployments public ip address and go explore your deployment

9. Your geth client should now be connected. Grab your IP or DNS name from the deployment outputs or the Azure portal and visit your cakeshop portal at http://{hostname}.com:8080/cakeshop

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
6. Your geth client should now be connected. Grab your IP or DNS name from the deployment outputs or the Azure portal and visit your cakeshop portal at http://{hostname}.com:8080/cakeshop

## Usage (Additional nodes)

Follow the steps for creating a custom node above. However, note these differences:

1. You will be required to provide values for the additional `config.json` fields: `AzureTableStorageName` and `AzureTableStorageSas`. These should be provided by whom ever established the first node.

2. You will deploy using the `additionalMember.json` template file.

```
    ./deploy-node.sh -n myrg -l westeurope -t ./arm/additionalMember.json -p ./arm/additionalMember.parameters.json -d ./additionalMemberNode
```

3. Once the deployment has completed, you quorum node should be connected to *atleast* the first member in the network. **NOTE:** This deployment will not stand up a Cakeshop, LogScrapper or Bootnode container.

4. If the new member has a `voter` and/or `blockmaker` role and is not defined within the `genesis.json` file as such. An existing member with the desired role needs to grant them permissions. This can be done by invoking either the `addVoter(0x...)` or `addBlockmaker(0x...)` functions against the [block_voting](https://github.com/jpmorganchase/quorum/blob/master/core/quorum/block_voting.sol) contract. I've included some helper scripts under `./source/geth/utils/` for doing this: `./source/geth/utils/addVoter "0x..."` on an existing node.

## Diagram
<img src="images/quorum-deploy.png?raw=true" />