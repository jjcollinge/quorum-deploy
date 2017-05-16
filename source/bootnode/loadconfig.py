import json
import os

with open('/opt/bootnode/config.json', "r") as config_file:
    config = json.load(config_file)

with open('/opt/bootnode/env.sh', "w") as env_file:
    for key, value in config.items():
        key=key.upper()
        env_file.write("{0}=\"{1}\"\n".format(key, value))