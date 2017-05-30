# Quorum Deploy
**Quorum Deploy** aims to provide a simple way to stand up a consortium quorum network on Azure.

* NOTE: This repository contains work in progress code which may or may not be in a working state at any given point in time. Depending on the requirements, I may create a stable branch at a later date.

## Usage
The below instructions are not implementation specific but could be performed using the Azure PowerShell SDK, Azure CLI or Azure CLI 2.0.

### First Member
In order to help bootstrap the rest of the network and provide some additional plugin points you must initially deploy a *first member*. There is a separate Azure Resource Manager (ARM) template for doing this as it requires slightly different parameters and invokes a different initialisation script.

1. Create a new resource group
2. Create and populate a firstMember.parameters.json file
3. Deploy the firstMember.json template along with your parameters file to your new resource group
4. Wait, this will take a little while to deploy the components and run the initialisation script
5. Once deployed, you should have a virtual machine running the following containers:
* Geth (Quorum fork)
* Constellation
* Cakeshop
* Bootnode

### Additional Members
Once the first member has been deployed, you can deploy additional members into new resource groups, subscriptions or accounts by using the additionalMember ARM template with an accompanying parameters file. The additional members template will only provision a single virtual machine running Geth (Quorum fork) and Constellation.

### Networking
The ARM template will configure the Network Security Group to allow on required ports to be open.

Geth (Quorum fork) will use the following ports by default:
* **30303/tcp** for node synchronisation
* **30303/udp** for node discovery
* **8545/tcp** for JSON RPC

Constellation will by default use the following ports by default:
* **9000/tcp** for message exchange

Cakeshop will listen on the following ports by default:
* **8080/tcp** for webserver (http://{FQDN}:8080/cakeshop for homepage)
* **30301/tcp** for local geth node sychronisation
* **30301/udp** for local geth node discovery

Bootnode will listen on the following ports by default:
* **33445/udp** for node discovery

### Membership and Roles
A node within a Quorum network can possess 3 roles.

* Observer
* Voter
* Block Maker

Using the parameters file you can configure your node to take on any of these roles. For Voter or Block Maker accounts, keys will be required to secure their transactions. Therefore, please run the provided ./create-key.sh script inside your node directory.

>NOTE: There must be atleast one Block Maker in the network at any given time.

It is advisable to make sure that your consortium members, their roles and an initial ether balance are defined within your `genesis.json` file. However, should you need to dynamically add members later, you can do so.

#### Dynamic Membership
To add new Voter or Block Maker who are not baked into your genesis.json file, you will need to get another member of the consortium with the desired role (i.e. a Voter) to manually add the new account address to the Quorum voting contract.
There are some helper scripts available under `source/geth/utils` which can make this easier.
For instance:

    ./addBlockmaker.sh $BLOCKMAKER_ADDRESS

Will attempt to add the given address to the Quorum voting contract as a Blockmaker. Assuming all the relevant keys have been setup, the account should start creating blocks shortly.

### Azure Storage
These scripts and templates make use of Azure Table Storage to store information about existing nodes. This helps any new nodes coming online quickly discover the other nodes in the network.

 >This is an external dependency and Azure Storage will not be provisioned as part of the deployment.

