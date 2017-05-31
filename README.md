# Quorum Deploy
**Quorum Deploy** aims to provide a simple way to stand up a consortium quorum network on Azure.

* NOTE: This repository contains work in progress code which may or may not be in a working state at any given point in time. Depending on the requirements, I may create a stable branch at a later date.

## Dependencies

 **Azure Storage**

These scripts and templates make use of Azure Table Storage to store information about existing nodes. This helps any new nodes coming online quickly discover the other nodes in the network.
These scripts also use Azure Blob Storage for storing a node's keys.

 >This is an external dependency and Azure Storage will not be provisioned as part of the deployment. Therefore, please provision an Azure Storage Account before attempting to use these scripts.

## Usage
The first thing you'll need to do is configure your consortium. This can be done in 2 different ways.

The simplist and most effective way is for each member to generate their own keys in relation to their role (see Membership and Roles) in the consortium. Using each of the consortium member's public keys, you can now generate a shared `genesis.json` file using this [tool](https://github.com/davebryson/quorum-genesis).

Alternatively, you can generate an initial subset of consortium member keys, create a shared `genesis.json` file like above and then dynamically add new members after the network is up and running.

I've included a helper script `create-keys.sh` which will allow you to create keys for nodes.

### Configure First Member
Once we have our member keys (see above) we need to zip them up and upload them to our Azure Blob Storage account. We need to use the blob container name `keys` and the blob file name `keys.zip`.

> NOTE: This is the same Azure Storage Account we'll use for storing the Geth bootnodes in.

Next we need to copy the example parameters file to a usuable parameters file name

```cp arm/firstMember.parameters.json.example arm/firstMember.parameters.json```

Now we can open the parameters file with a text editor and populate the values accordingly. The parameters and addresses must match up with the keys you've just generated. Similarly, the Azure Storage Account details must be the same account you stored the keys earlier. You can leave the `OtherConstellationNodes` blank as we have no other nodes to connect to yet.

### Deploy First Member
In order to help bootstrap the rest of the network and provide some additional plugin points you must initially deploy just the *first member*. This can be done using the Azure PowerShell SDK as below, or using the Azure CLI.

1. Log in to Azure

    ```Login-AzureRmAccount```

2. Select the correct Azure subscription

    ```Select-AzureRmSubscription -SubscriptionId <desired-subscription-id>```

3. Create a new resource group

    ```New-AzureRmResourceGroup -Name <name> -Location <location>```

4. Deploy the firstMember.json template along with your parameters file to your new resource group

    ```New-AzureRmResourceGroupDeployment -Name dotjsonquorum -ResourceGroupName dotjsonq -TemplateFile .\arm\firstMember.json -TemplateParameterFile .\arm\firstMember.parameters.json -Verbose```

5. Wait... this will take a little while to deploy the components and run the initialisation script. The `-Verbose` flag will enable feedback so you can see how the deployment is progressing.

6. Once deployed, you should have a virtual machine running the following containers:
* Geth (Quorum fork)
* Constellation
* Cakeshop
* Bootnode

You can test this by connecting to the VM via ssh and running

```docker ps```

You can then inspect the status of any of the running containers by entering them using

```docker exec -it <containerid> /bin/bash```

### Configure Additional Members
Once the first member has been deployed, you can deploy additional members into new resource groups, subscriptions or accounts.

You will be required to provide a SAS token for access to the first memeber's Azure Table Storage account.
You will also need to provide credentials for your own Azure Storage account where you have stored your node's keys, as described in *Configure First Member*.

### Deploy Additional Members
When you have your keys stored in Azure Blob Storage and you've populated your paramters file. You can simply deploy the `additionalMember.json` ARM template along with your `additionalMember.parameters.json` parameters file.
This will provision a single Linux virtual machine running Geth (Quorum fork) and Constellation docker containers only. Geth should discover existing members in the network by looking up addresses in the provided Azure Table Storage.

### Networking
The ARM template will configure the Network Security Group to allow on;y required ports to be open.

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

Using the parameters file you can configure your node to take on any of these roles. For Voter or Block Maker accounts, keys will be required to secure their transactions. Therefore, please run the provided `create-key.sh` script inside as described above.

>NOTE: There must be atleast one Block Maker in the network at any given time.

It is advisable to make sure that your consortium members, their roles and an initial ether balance are defined within your `genesis.json` file. However, should you need to dynamically add members later, you can do so.

#### Dynamic Membership
To add a new Voter and/or Block Maker who are not baked into your genesis.json file, you will need to get another member of the consortium with the desired role (i.e. an existing Voter) to manually add the new account address to the Quorum voting contract.
There are some helper scripts available under `source/geth/utils` which can make this easier.
For instance:

    ./addBlockmaker.sh $BLOCKMAKER_ADDRESS

This will attempt to add the given address to the Quorum voting contract as a Blockmaker. Assuming all the relevant keys have been setup, the account should be granted permissions to start creating blocks shortly.

