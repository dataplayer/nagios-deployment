
###########################################################################
# This Python code generates
# Nagios config files from a json list of service defintions
#
# Usage:
# > python python generateServices.py services.json
#
# by Nic Flores
###########################################################################

import sys
import os
import json


# one host definition per file
def gen_hosts(data):
	for i in data:
		hf = open('./services/' + i + '.cfg','w+')
		for j in data[i]:
			hf.write("define service {\n")
			for k,v in j.items():
				hf.write("\t%-20s\t%s\n" % (k,v))
			hf.write("}\n")
		hf.close()		


def main(args):
	pathtofile = args[0]
	f = open(pathtofile,'r')
	data = json.load(f)
	gen_hosts(data)
	f.close()

if __name__ == '__main__':
	main(sys.argv[1:])
