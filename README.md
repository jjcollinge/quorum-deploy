# Quorum Node
Quorum node is a simply way to spin up a new quorum node in a Docker container. The node can be configured to stand alone, initialise a new network or join an existing Quorum network.

## Usage
1. Firstly clone the repository to your local machine
```
git clone https://github.com/jjcollinge/quorum-node.git
```

2. Rename the example configuration files in the `config` directory by running this command
```
cd quorum-node/config && \
mv env.sh.example env.sh && \
mv genesis.json.example genesis.json && \
mv gethbootstrap.sh.example gethbootstrap.sh && \
mv node.conf.example node.conf
```

3. Customise the configuration files in the `quorum-node/config` directory to map to your desired network configuration.

4. (Optional) Generate constellation and/or geth keys and store them in `/quorum-node/keys`. Alternatively, generate the keys at runtime by using the command shown in step 6.2 below.

5. Build the container from the Dockerfile: `docker built -t ext-node .`

6. Run the container;
    1. for pre-generated keys: `docker run -d --net=host ext-node`
    2. To generate keys: `docker run -it --net=host ext-node`

**NOTE** You can ONLY currently generate keys for an observer node. If you want to configure your node as a voter or a blockmaker, then please generate the keys beforehand and provide the necessary geth arguments in `quorum-node/config/gethbootstrap.sh`

**WARNING** The initial build of the quorum-node docker image will take a little while, however, subsequent builds will use the local cache and will be considerably faster.



