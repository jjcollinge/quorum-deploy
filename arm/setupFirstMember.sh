#!/bin/bash

# Deploy quorum, constellation and bootnode
cd /opt
git clone https://github.com/jjcollinge/quorum-node --branch feature/registry

# Deploy cakeshop
git clone https://github.com/jpmorganchase/cakeshop.git

# Deploy .NET web app
git clone https://github.com/jjcollinge/quorum-web.git