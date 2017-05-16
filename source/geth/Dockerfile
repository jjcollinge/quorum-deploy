FROM ubuntu:16.04

ENV GOREL go1.7.3.linux-amd64.tar.gz
ENV PATH $PATH:/usr/local/go/bin

RUN apt-get update && apt-get upgrade -q -y && \
    apt-get update && \
    apt-get install -y --no-install-recommends wget git make gcc libc-dev ca-certificates

RUN wget -q https://storage.googleapis.com/golang/${GOREL} && \
  tar -xvzf ${GOREL} && \
  mv go /usr/local/go && \
  rm ${GOREL}

RUN \
    git clone https://github.com/jpmorganchase/quorum.git && \
    cd quorum && git checkout tags/q1.0.1 && make geth && \
    cp build/bin/geth /usr/local/bin && \
    chmod +x /usr/local/bin/* && \
    cd .. && \
    rm -rf /quorum

RUN apt-get install -y \
    libssl-dev \
    libffi-dev \
    python3-dev \
    python3-pip && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    apt-get clean

RUN echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ wheezy main" | tee /etc/apt/sources.list.d/azure-cli.list && \
    apt-key adv --keyserver packages.microsoft.com --recv-keys 417A0893 && \
    apt-get install -y apt-transport-https --no-install-recommends && \
    apt-get update && \
    apt-get install -y azure-cli software-properties-common

RUN add-apt-repository -y ppa:ethereum/ethereum && \
    apt-get update && \
    apt-get install -y solc

# Clean up packages
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create directory structure
RUN mkdir -p /opt/quorum /opt/quorum/temp /opt/quorum/data /opt/quorum/data/keystore /opt/quorum/temp/logs /opt/quorum/keys

# Copy source and key files into the container
COPY . /opt/quorum

RUN chmod +x /opt/quorum

# Expose ports
EXPOSE 30303
EXPOSE 30303/udp
EXPOSE 8545

# Mount data volume
VOLUME /data

WORKDIR /opt/quorum

ENTRYPOINT ["/opt/quorum/start.sh"]