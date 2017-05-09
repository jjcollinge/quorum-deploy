# Quorum Node
Quorum node is a simple way to spin up a new quorum node in a Docker container. The node can be configured to be stand-a-lone or connect to an existing network

## Configuring your node
If you do not have existing keys and config, you can use the `node-builder.sh` script to help configure your node.

follow the below steps to configure a new node:
1. Clone the repository to your local machine
```
git clone https://github.com/jjcollinge/quorum-node.git
```

2. Change the permissions on the scripts to allow them to run
```
chmod +x quorum-node/*.sh
```

3. Run the `node-builder.sh` script
```
cd quorum-node && ./node-builder.sh
```

4. Follow the on screen instructions to configure your Quorum node.

If you do not wish to use the helper script, you can manually modify the file in the `config` folder to setup your node.

## Build your node
Once you've configured your Quorum node, you can package it up a portable docker images using the following command:
```
docker build -t myqnode .
```
**WARNING** The initial build of the quorum-node docker image will take a little while, however, subsequent builds will use the local cache and will be considerably faster.

## Run your node
Finally, you can run your node using a similar command to the one below:
```
docker run -d --net=host myqnode
```

## Inspect your node
If you want to inspect your running node follow these instructions.
1. Get the docker container id from the list of containers
```
docker ps
```
2. Enter a new shell inside the container
```
docker exec -it <container_id> /bin/bash
```

Now that you are inside the container, you can view the logs in the `temp/logs/` folder. You can also attach to the running geth instance using `geth attach temp/data/geth.ipc`.



