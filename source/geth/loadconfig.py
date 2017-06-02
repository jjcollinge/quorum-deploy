#!/usr/bin/env python3
import json
import os

config_file = '/opt/quorum/config.json'
env_file = '/opt/quorum/env.sh'

with open(config_file, "r") as config_file:
    config = json.load(config_file)

with open(env_file, "w") as env_file:
    for key, value in config.items():
        key=key.upper()
        env_file.write("{0}=\"{1}\"\n".format(key, value))