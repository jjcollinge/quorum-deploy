import json
import os
import glob
import subprocess
import time
import re
from distutils.dir_util import copy_tree
import shutil
from pprint import pprint

def execute(cmd):
    process = subprocess.Popen(cmd.split(), stdout=subprocess.PIPE)
    output, error = process.communicate()
    if(error):
        raise Exception(error)
    return output

with open('src/config.json') as config_file:
    config = json.load(config_file)

# Pretty print config
pprint(config)

# Define global constants
node_root_path = "/quorum-node"
temp_path = node_root_path + "/temp"
data_path = temp_path + "/data"
key_path = node_root_path + "/keys"
src_path = node_root_path + "/src"
keystore_path = data_path + "/keystore"
bootnode_keyfile_path = node_root_path + "/bootnode"
local_ip = "127.0.0.1"
azure_storage_table = "networkbootnodes"
azure_partition_key = "100"
azure_row_key = config["GethNetworkId"]
cwd = os.getcwd()

# Set required enviroment variables
os.environ['AZURE_STORAGE_ACCOUNT'] = config["AzureStorageAccount"]
os.environ['AZURE_STORAGE_ACCESS_KEY'] = config["AzureStorageSAS"]

# Login to Azure Storage with SPN
execute("az login --service-principal -u {0} -p {1} --tenant {2}".format(config["AzureSPNAppId"], config["AzureSPNPassword"], config["AzureTenant"]))

# Copy key files into keystore
for key in glob.glob(key_path + '/key*'):
    copy_tree(key, keystore_path)

# Initialise Geth
execute("geth --datadir {0} init config/genesis.json".format(data_path))

if (config["IsBootnode"] == True):
    # Start a local bootnode if required
    if not os.path.exists(bootnode_keyfile_path):
        execute("bootnode -genkey {0}".format(bootnode_keyfile_path))
    execute("nohup bootnode --nodekey {0} --addr {1}:5000 2>> temp/logs/bootnode.log &".format(bootnode_keyfile_path, local_ip))
    # Grab the bootnode public key
    bootnode_publickey = execute("cat bootnode.key")
    # Register bootnode with table storage
    exists = execute("az storage table exists -n {0}".format(azure_storage_table))
    if (exists == False):
        # Create table if it doesn't exist
        execute("az storage table create -n {0}".format(azure_storage_table))
    # Fetch current value
    current_bootnodes = execute("az storage entity show -t {0} --partition-key {1} --row-key {2}".format(azure_storage_table, azure_partition_key, azure_row_key))
    # Update the values to include the local bootnode
    bootnode_enode = "enode://{0}@[::]:5000".format(bootnode_publickey)
    current_bootnodes += ',' + bootnode_enode
    execute("az storage entity merge -t {0} -e PartitionKey={1} RowKey={2} Content={3}".format(azure_storage_table, azure_partition_key, azure_row_key, current_bootnodes))
    # Clear other urls in node.conf
    execute("sed -i -e 's/__OTHER_NODE_URLS__//g' src/node.conf")
else:
    # Fetch current value
    current_bootnodes = execute("az storage entity show -t {0} --partition-key {1} --row-key {2}".format(azure_storage_table, azure_partition_key, azure_row_key))
    # Add bootnode IP as constellation node
    p = '(?:enode//)?(?P<host>[^:/ ]+).?(?P<port>[0-9]*).*'
    m = re.search(p, current_bootnodes.split(',')[0])
    host_ip = m.group('host')
    execute("sed -i -e 's/__OTHER_NODE_URLS__/\"{0}:5000\"/g' src/node.conf".format(host_ip))

# Start local constellation
shutil.copy(src_path + "/node.conf", cwd)
execute("nohup constellation-node node.conf 2>> temp/logs/constellation.log &")

# Allow constellation time to come up
time.sleep(10)

# Start Geth
args = """--datadir {0} --bootnodes {1} --networkid {2} --rpc --rpcaddr 0.0.0.0
          ---rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,quorum
          --rpcport 8545 --port 30303""".format(data_path, current_bootnodes, config["GethNetworkId"])
if (config["IsVoter"] == True):
    args += "--voteaccount {0} --votepassword {1} ".format(config["VoterAccountAddress"], config["VoterAccountPassword"])
if (config["IsBlockMaker"] == True):
    args += "--blockmakeraccount {0} --blockmakerpassword {1} ".format(config["BlockmakerAccountAddress"], config["BlockmakerAccountPassword"])
execute("nohup geth {0} & 2>> temp/logs/geth.log")

# Keep container alive
execute("tail -f /dev/null")





