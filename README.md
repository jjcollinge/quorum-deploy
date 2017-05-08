# Quorum Node
Quorum node is a simply way to spin up a new quorum node in a Docker container. The node can be configured to stand alone, initialise a new network or join an existing Quorum network.

## Usage
1. Firstly clone the repository to your local machine
`git clone https://github.com/jjcollinge/quorum-node.git`

2. Customise the configuration files `/quorum-node/config` to suitable values for your network.

3. (Optional) Generate constellation and geth keys and store them in `/quorum-node/keys`, alternatively, you can dynamically create this by providing an empty keys folder.

3. Build the container; `docker built -t ext-node .`

4. Run the container; `docker run -d --net=host ext-node`



