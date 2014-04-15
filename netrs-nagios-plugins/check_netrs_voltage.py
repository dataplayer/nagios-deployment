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
            "usage: {0} -h <NetRS url> -p <port num (optional) -t <timeout (default=8sec)> -l <usr:pass>".format(sys.argv[0]))

def nagios_return(code, response):
    """ prints the response message
        and exits the script with one
        of the defined exit codes
        DOES NOT RETURN 
    """
    print code + ": " + response
    sys.exit(nagios_codes[code])

def parse_message(result):
    """ Parses the result of a temp query to receiver
        determines the status and returns message and ststus
    """
    #print(result)
    res = ''
    ressplit = result.split()
    port2volts = ressplit[2].split('=')
    v = float(port2volts[1])
    if v >= 12.5:
      return {"code": "OK", "message": "Voltage on port 2 is "+str(v)}
    elif v > 12.4 and v < 11.4:
      return {"code": "WARNING", "message": "Voltage on port 2 is "+str(v)}
    elif v < 11.4:
      return {"code": "CRITICAL", "message": "Voltage on port 2 is "+str(v)}
    return {"code": "UNKNOWN", "message": "Voltage on port 2 is "+str(v)}


def check_condition(host,timeout,hostname):
    """ a dummy check
        doesn't really check anything 
    """
    buf = cStringIO.StringIO()

    c = pycurl.Curl()
    c.setopt(c.URL,host)

    if hostname != '':
      hname = hostname[:4].lower()
      c.setopt(pycurl.USERPWD, "%s:%s" % (hname, hname+'4gps'))

    c.setopt(c.WRITEFUNCTION,buf.write)
    c.setopt(c.CONNECTTIMEOUT, timeout)
    c.setopt(c.FAILONERROR, True)
    try:
      c.perform()
    except pycurl.error, error:
      errno, errstr = error
      return {"code": "WARNING", "message": "Error:"+ errstr}

    message = parse_message(buf.getvalue())
    buf.close()
    return message

def main():
    """ example options processing
        here we're expecting 1 option "-h"
        with a parameter
    """
    timeout = 8
    if len(sys.argv) < 2:
        usage()

    try:
        options, args = getopt.getopt(sys.argv[1:], "h:p:t:n:")
    except getopt.GetoptError, err:
        usage()

    for opt, arg in options:
        if opt in ('-h','-H','-host'):
            host = 'http://'+arg
	elif opt in ('-p','-port','--p','--port'):
	    host += ':'+arg
        elif opt in ('-t','-timeout','--t','--timeout'):
            timeout = int(arg)
        elif opt in ('-n','--n','-name','--name'):
            hostname = arg
        else:
            usage()
    host += '/prog/Show?Voltage&input=2'
    #print(host)

    result = check_condition(host,timeout,hostname)
    nagios_return(result['code'], result['message'])

if __name__ == "__main__":
    main()
