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
            "usage: {0} -h <NetR9 url> -p <port num (optional) -t <timeout (default=8sec)>".format(sys.argv[0]))

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
    tempres = ressplit[1].split('=')
    t = float(tempres[1])
    if t > -20 and t < 50:
      return {"code": "OK", "message": ressplit[1]}
    elif (t > -40 and t < -20) or (t > 50 and t < 65):
      return {"code": "WARNING", "message": ressplit[1]}
    elif t < -40 or t > 65 :
      return {"code": "CRITICAL", "message": ressplit[1]}
    return {"code": "UNKNOWN", "message": result}
     

def check_condition(host,timeout):
    """ a dummy check
        doesn't really check anything 
    """
    buf = cStringIO.StringIO()

    c = pycurl.Curl()
    c.setopt(c.URL,host)
    c.setopt(c.WRITEFUNCTION,buf.write)
    c.setopt(c.CONNECTTIMEOUT, timeout)
    c.setopt(c.FAILONERROR, True)
    try:
      c.perform()
    except pycurl.error, error:
      errno, errstr = error
      return {"code": "CRITICAL", "message": "Error:"+ errstr}

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
        options, args = getopt.getopt(sys.argv[1:], "h:p:t")
    except getopt.GetoptError, err:
        usage()

    for opt, arg in options:
        if opt in ('-h','-H','-host'):
            host = 'http://'+arg
	elif opt in ('-p','-port','--p','--port'):
	    host += ':'+arg
        elif opt in ('-t','-timeout','--t','--timeout'):
            timeout = arg
        else:
            usage()
    host += '/prog/show?temperature'
    #print(host)

    result = check_condition(host,timeout)
    nagios_return(result['code'], result['message'])

if __name__ == "__main__":
    main()
