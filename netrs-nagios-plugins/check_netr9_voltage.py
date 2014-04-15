#!/usr/bin/env python

import sys, getopt, pycurl, cStringIO

nagios_codes = {'OK': 0, 
                'WARNING': 1, 
                'CRITICAL': 2,
                'UNKNOWN': 3,
                'DEPENDENT': 4}

def usage():
    """ returns nagios status UNKNOWN with 
        a one line usage description
        usage() calls nagios_return()
    """
    nagios_return('UNKNOWN', 
            "usage: {0} -h <NetR9 url> -p <port num (optional)>".format(sys.argv[0]))

def nagios_return(code, response):
    """ prints the response message
        and exits the script with one
        of the defined exit codes
        DOES NOT RETURN 
    """
    print code + ": " + response
    sys.exit(nagios_codes[code])

def parse_voltage(result):
    """ cleans up the returned 
        voltage message
    """
    res = ''
    ressplit = result.split()
    port2volts = ressplit[12].split('=')
    v = float(port2volts[1])
    if v >= 12.5:
      return {"code": "OK", "message": ressplit[10]+' '+ressplit[11]+' '+ressplit[12]+' '+ressplit[13]}
    elif v > 12.4 and v < 11.4:
      return {"code": "WARNING", "message": ressplit[10]+' '+ressplit[11]+' '+ressplit[12]+' '+ressplit[13]}
    elif v < 11.4:
      return {"code": "CRITICAL", "message": ressplit[10]+' '+ressplit[11]+' '+ressplit[12]+' '+ressplit[13]}
    return {"code": "UNKNOWN", "message": ressplit[10]+' '+ressplit[11]+' '+ressplit[12]+' '+ressplit[13]}
     

def check_condition(host):
    """ a dummy check
        doesn't really check anything 
    """
    buf = cStringIO.StringIO()

    c = pycurl.Curl()
    c.setopt(c.URL,host)
    c.setopt(c.WRITEFUNCTION,buf.write)
    c.setopt(c.FAILONERROR, True)
    try:
      c.perform()
    except pycurl.error, error:
      errno, errstr = error
      return {"code": "CRITICAL", "message": "Error:"+ errstr}

    message = parse_voltage(buf.getvalue())
    buf.close()
    return message
    #return {"code": "OK", "message": voltage }

def main():
    """ example options processing
        here we're expecting 1 option "-h"
        with a parameter
    """

    if len(sys.argv) < 2:
        usage()

    try:
        options, args = getopt.getopt(sys.argv[1:], "h:p:")
    except getopt.GetoptError, err:
        usage()

    for opt, arg in options:
        if opt in ('-h','-H','-host'):
            host = 'http://'+arg
	elif opt in ('-p','-port','--p','--port'):
	    host += ':'+arg
        else:
            usage()
    host += '/prog/show?voltages'

    result = check_condition(host)
    nagios_return(result['code'], result['message'])

if __name__ == "__main__":
    main()
