# Quorum Node
Quorum node is a simply way to spin up a new quorum node in a Docker container. The node can be configured to stand alone, initialise a new network or join an existing Quorum network.

## Usage
1. Firstly clone the repository to your local machine
`git clone https://github.com/jjcollinge/quorum-node.git`

2. Customise the configuration files `/quorum-node/config` to suitable values for your network.

3. (Optional) Generate constellation and geth keys and store them in `/quorum-node/keys`. Alternatively, generate the keys at runtime using the second run command below.

3. Build the container; `docker built -t ext-node .`

4. Run the container;
    1. for pre-generated keys: `docker run -d --net=host ext-node`
    2. To generate keys: `docker run -it --net=host ext-node`



