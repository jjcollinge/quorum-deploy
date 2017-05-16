FROM ubuntu:16.04

# Install deps
RUN apt-get update && \
    apt-get install -y wget unzip libdb-dev libsodium-dev zlib1g-dev libtinfo-dev libgmp3-dev

# Fetch constellation
RUN wget -q https://github.com/jpmorganchase/constellation/releases/download/v0.0.1-alpha/ubuntu1604.zip && \
    unzip ubuntu1604.zip

# Set up paths
RUN chmod +x /ubuntu1604/* && \
    cp /ubuntu1604/constellation* /usr/local/bin && \
    rm -rf ubuntu1604 && \
    rm -f ubuntu1604.zip

# Copy in constellation config
RUN mkdir -p /opt/constellation/keys
COPY node.conf /opt/constellation
COPY keys /opt/constellation/keys

WORKDIR /opt/constellation

# Expose ports
EXPOSE 9000

ENTRYPOINT ["constellation-node", "node.conf"]
