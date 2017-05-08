# Quorum Node
Quorum node is a simply way to spin up a new quorum node in a Docker container. The node can be configured to stand alone, initialise a new network or join an existing Quorum network.

## Usage
1. Firstly clone the repository to your local machine
```
git clone https://github.com/jjcollinge/quorum-node.git
```

2. Rename the example configuration files by running the commands
```
 mv env.sh.example env.sh && \
 mv genesis.json.example genesis.json && \
 mv gethbootstrap.sh.example gethbootstrap.sh && \
 mv node.conf.example node.conf
```

3. Customise the configuration files `/quorum-node/config` to suitable values for your network.

4. (Optional) Generate constellation and geth keys and store them in `/quorum-node/keys`. Alternatively, generate the keys at runtime using the second run command below.

5. Build the container; `docker built -t ext-node .`

6. Run the container;
    1. for pre-generated keys: `docker run -d --net=host ext-node`
    2. To generate keys: `docker run -it --net=host ext-node`



