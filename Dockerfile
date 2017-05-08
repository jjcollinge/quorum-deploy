FROM ubuntu:16.04
ENV GOREL go1.7.3.linux-amd64.tar.gz
ENV PATH $PATH:/usr/local/go/bin

RUN apt-get update &&  apt-get install -y
RUN apt-get install -y software-properties-common unzip wget git make gcc libsodium-dev build-essential libdb-dev zlib1g-dev libtinfo-dev sysvbanner wrk psmisc
RUN add-apt-repository -y ppa:ethereum/ethereum &&  apt-get update && apt-get install -y solc
RUN wget -q https://github.com/jpmorganchase/constellation/releases/download/v0.0.1-alpha/ubuntu1604.zip && unzip ubuntu1604.zip

RUN wget -q https://storage.googleapis.com/golang/${GOREL}
RUN tar -xvzf ${GOREL}
RUN mv go /usr/local/go
RUN rm ${GOREL}

RUN git clone https://github.com/jpmorganchase/quorum.git
RUN cd quorum && git checkout tags/q1.0.1 && make all

RUN chmod +x /quorum/build/bin/* && \
    cp /quorum/build/bin/* /usr/local/bin && \
    chmod +x /ubuntu1604/* && \
    cp /ubuntu1604/constellation* /usr/local/bin

COPY start.sh /start.sh
RUN chmod +x start.sh

COPY config /quorum-node/config

ENTRYPOINT ["/bin/bash"]