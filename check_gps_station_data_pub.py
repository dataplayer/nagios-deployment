##########################################
# This Nagios plugin will alert if date 
# are are no longer bing published for a
# particular GPS station.
#
# Requierments: you must run station_date.py
# from within the directory containing the 
# various java api jars provided by unavco.org.
# Here is the download link:
# http://facility.unavco.org/data/dai2/dai2-api.html
#
#
# Author: Nic Flores 
# GNU General Public License
##########################################


import os
import sys
import subprocess
import time, datetime


def main(arg):
	station = arg[0]
	warning = datetime.timedelta(seconds = int(arg[1]))
	critical = datetime.timedelta(seconds = int(arg[2]))
	p = subprocess.Popen("java -jar ./unavcoMetadata.jar -permanent -newestOnly -4charEqu " + station,stdout=subprocess.PIPE,shell=True)
	(output,err) = p.communicate()
	if (not err):
		s = output.split("\n")
		c = s[1].split(",")

		currtime = datetime.datetime.utcnow()
		atime = datetime.datetime.strptime(c[6],"%Y-%m-%dT%H:%M:%S.%fZ")
		tdiff = currtime - atime

		if (tdiff < warning):
			print "OK: Data is current " + str(tdiff)
			sys.exit(0)
		elif (tdiff >= warning and tdiff < critical):
			print "Warning: No data for " + str(tdiff) 
			sys.exit(1)
		elif (tdiff >= critical):
			print "Critical: No data for " + str(tdiff)
			sys.exit(2)
		else:
			print "Undefined"
			sys.exit(3)
	else:
		print err

if __name__ == '__main__':
	if len(sys.argv[1:]) < 1 or sys.argv[1] == "-h" or sys.argv[1] == "--help":
		print "usage:> python check_gps_station_data_pub.py <4charID> <warning in seconds> <critial in seconds>"
		sys.exit()
	main(sys.argv[1:])
	
