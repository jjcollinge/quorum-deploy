FROM ubuntu:16.04

ENV GOREL go1.7.3.linux-amd64.tar.gz
ENV PATH $PATH:/usr/local/go/bin

# Install build tools
RUN apt-get update &&  apt-get install --no-install-recommends -y \
    software-properties-common \
    unzip \
    wget \
    git \
    make \
    gcc \
    libsodium-dev \
    build-essential \
    libdb-dev \
    zlib1g-dev \
    libtinfo-dev \
    sysvbanner wrk \
    psmisc \
    curl

# Install python
RUN apt-get install -y \
    libssl-dev \
    libffi-dev \
    python3-dev \
    python3-pip && \
    ln -s /usr/bin/python3 /usr/bin/python

# Install solidity compiler
RUN add-apt-repository -y ppa:ethereum/ethereum && \
    apt-get update && \
    apt-get install -y solc

# Fetch constellation
RUN wget -q https://github.com/jpmorganchase/constellation/releases/download/v0.0.1-alpha/ubuntu1604.zip && \
    unzip ubuntu1604.zip

# Install Go
RUN wget -q https://storage.googleapis.com/golang/${GOREL} && \
    tar -xvzf ${GOREL} && \
    mv go /usr/local/go && \
    rm ${GOREL}

# Fetch and build Quorum
RUN git clone https://github.com/jpmorganchase/quorum.git && \
    cd quorum && \
    git checkout tags/q1.0.1 && \
    make all

# Set up paths
RUN chmod +x /quorum/build/bin/* && \
    cp /quorum/build/bin/* /usr/local/bin && \
    chmod +x /ubuntu1604/* && \
    cp /ubuntu1604/constellation* /usr/local/bin && \
    rm -rf quorum && \
    rm -rf ubuntu1604 && \
    rm -f ubuntu1604.zip

# Install Azure Cli 2.0
RUN echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ wheezy main" | tee /etc/apt/sources.list.d/azure-cli.list && \
    apt-key adv --keyserver packages.microsoft.com --recv-keys 417A0893 && \
    apt-get install -y apt-transport-https --no-install-recommends && \
    apt-get update && \
    apt-get install -y azure-cli

# Clean up packages
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create directory structure
RUN mkdir -p /opt/quorum /opt/quorum/temp /opt/quorum/data /opt/quorum/data/keystore /opt/quorum/temp/logs

# Copy source and key files into the container
COPY src /opt/quorum/src
COPY keys /opt/quorum/keys

# Set permissions
RUN chmod +x /opt/quorum/src/start.sh

# Expose ports
EXPOSE 30303
EXPOSE 30303/udp
EXPOSE 8545
EXPOSE 9000
EXPOSE 33445/udp

# Mount data volume
VOLUME /data

WORKDIR /opt/quorum/

 ENTRYPOINT ["/bin/bash"]
# ENTRYPOINT ["./src/start.sh"]