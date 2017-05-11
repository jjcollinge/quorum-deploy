FROM ubuntu:16.04

ENV GOREL go1.7.3.linux-amd64.tar.gz
ENV PATH $PATH:/usr/local/go/bin

RUN apt-get update &&  apt-get install -y \
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

RUN apt-get install -y \
    libssl-dev \
    libffi-dev \
    python3-dev \
    python3-pip && \
    ln -s /usr/bin/python3 /usr/bin/python

RUN add-apt-repository -y ppa:ethereum/ethereum && \
    apt-get update && \
    apt-get install -y solc && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN wget -q https://github.com/jpmorganchase/constellation/releases/download/v0.0.1-alpha/ubuntu1604.zip && \
    unzip ubuntu1604.zip

RUN wget -q https://storage.googleapis.com/golang/${GOREL} && \
    tar -xvzf ${GOREL} && \
    mv go /usr/local/go && \
    rm ${GOREL}

RUN git clone https://github.com/jpmorganchase/quorum.git && \
    cd quorum && \
    git checkout tags/q1.0.1 && \
    make all

RUN chmod +x /quorum/build/bin/* && \
    cp /quorum/build/bin/* /usr/local/bin && \
    chmod +x /ubuntu1604/* && \
    cp /ubuntu1604/constellation* /usr/local/bin && \
    rm -rf quorum && \
    rm -rf ubuntu1604 && \
    rm -f ubuntu1604.zip

RUN curl -L https://aka.ms/InstallAzureCli | bash

RUN mkdir -p /quorum-node/ \
    /quorum-node/temp \
    /quorum-node/temp/data \
    /quorum-node/temp/data/keystore

COPY src /quorum-node/src
COPY keys /quorum-node/keys

RUN chmod +x /quorum-node/src/setup.py

WORKDIR /quorum-node

ENTRYPOINT ["python ./src/setup.py"]