import json
import sys

config_file = '/opt/quorum/config.json'

with open(config_file, 'r') as json_file:
    json_decoded = json.load(json_file)

args = sys.argv[1:]
print args
kvps = dict(arg.split('=',1) for arg in args)

for key, value in kvps.iteritems():
    json_decoded[key] = value

with open(config_file, 'w') as json_file:
    json.dump(json_decoded, json_file, indent=4, separators=(',', ': '))