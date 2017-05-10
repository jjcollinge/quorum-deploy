import json
import os
import glob
import subprocess
import time
from distutils.dir_util import copy_tree
import shutil
from pprint import pprint

def create_dir_if_not_exist(dir_path):
    if not os.path.exists(dir_path):
        os.makedirs(dir_path)

def execute(cmd):
    process = subprocess.Popen(cmd.split(), stdout=subprocess.PIPE)
    output, error = process.communicate()
    if(error):
        raise Exception(error)
    return output

with open('config/config.json') as config_file:
    config = json.load(config_file)

# Pretty print config
pprint(config)

# Define global constants
node_root_path = "/quorum-node"
temp_path = node_root_path + "/temp"
data_path = temp_path + "/data"
key_path = node_root_path + "/keys"
config_path = node_root_path + "/config"
keystore_path = data_path + "/keystore"
azure_storage_table = "myuniquenetworkid"
azure_partition_key = "mypartitionkey"
azure_row_key = "myrowkey"
cwd = os.getcwd()

# Set required enviroment variables
os.environ['AZURE_STORAGE_ACCOUNT'] = config["AzureStorageAccount"]
os.environ['AZURE_STORAGE_ACCESS_KEY'] = config["AzureStorageSAS"]

# Login to Azure Storage with SPN
cmd = "az login --service-principal -u {0} -p {1} --tenant {2}".format(config["AzureSPNAppId"], config["AzureSPNPassword"], config["AzureTenant"])
execute(cmd)

# Create desired directories
create_dir_if_not_exist(node_root_path)
create_dir_if_not_exist(temp_path)
create_dir_if_not_exist(data_path)
create_dir_if_not_exist(keystore_path)

# Copy key files into keystore
for key in glob.glob(key_path + '/key*'):
    copy_tree(key, keystore_path)

# Initialise Geth
cmd = "geth --datadir {0} init config/genesis.json".format(data_path)
execute(cmd)

if (config["IsBootnode"] == True):
    # Start a local bootnode if required
    cmd = 'nohup bootnode -genkey bootnode.key --addr="127.0.0.1:5000" &'
    execute(cmd)
    # Grab the bootnode public key
    cmd = "cat bootnode.key"
    bootnode_publickey = execute(cmd)
    # Register bootnode with table storage
    cmd = "az storage table exists -n {0}".format(azure_storage_table)
    exists = execute(cmd)
    if (exists == "false"):
        # Create table if it doesn't exist
        cmd = "az storage table create -n {0}".format(azure_storage_table)
        execute(cmd)
    # Fetch current value
    cmd = "az storage entity show -t {0} --partition-key {1} --row-key {2}".format(azure_storage_table, azure_partition_key, azure_row_key)
    current_bootnodes = execute(cmd)
    # Update the values to include the local bootnode
    bootnode_enode = "enode://{0}@[::]:5000".format(bootnode_publickey)
    current_bootnodes += ',' + bootnode_enode
    cmd = "az storage entity merge -t {0} -e PartitionKey={1} RowKey={2} Content={3}".format(azure_storage_table, azure_partition_key, azure_row_key, current_bootnodes)
    execute(cmd)
else:
    # Fetch current value
    cmd = "az storage entity show -t {0} --partition-key {1} --row-key {1}".format(azure_storage_table, azure_partition_key, azure_row_key)
    current_bootnodes = execute(cmd)

# Start local constellation
shutil.copy(config_path + "/node.conf", cwd)
cmd = "nohup constellation-node node.conf &"
execute(cmd)

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
cmd = "nohup geth {0} &"
execute(cmd)

# Keep container alive
cmd = "tail -f /dev/null"
execute(cmd)





