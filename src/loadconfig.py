import json
import os

cwd = os.getcwd()
src = cwd + "/src/"
with open(src + 'config.json', "r") as config_file:
    config = json.load(config_file)

with open(src + 'env.sh', "w") as env_file:
    for key, value in config.items():
        key=key.upper()
        env_file.write("{0}=\"{1}\"\n".format(key, value))