
#########################
# This Python code generates
# Nagios config files generated
# from a json list of host defintions
#
# Run this program from the command like so:
#
# python genhosts.py <path to JSON file>
#
# by Nic Flores
#########################

import sys
import os
import json


# one host definition per file
def gen_hosts(data):
	for i in data["hosts"]:
		hf = open('./hosts/' + i['host_name'] + '.cfg','w+')
		hf.write("define host {\n")
		for key, value in i.items():
			hf.write("\t%-15s\t%s\n" % (key, value))
		hf.write("}")
		hf.close()

def main(args):
	pathtofile = args[0]
	f = open(pathtofile,'r')
	data = json.load(f)
	gen_hosts(data)
	f.close()

if __name__ == '__main__':
	main(sys.argv[1:])
