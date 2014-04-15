#!/bin/bash

echo "installing needed software"
echo "hit the Enter key when you see 'Enter arithmetic or Perl expression: exit'"

sleep 4
yum install -y httpd php gcc glibc glibc-common gd gd-devel make net-snmp wget perl-CPAN rrdtool rrdtool-perl php-gd openssl-devel
export PERL_MM_USE_DEFAULT=1
export PERL_EXTUTILS_AUTOINSTALL="--defaultdeps"
perl -MCPAN -e "install Bundle::CPAN"
perl -MCPAN -e "install YAML"
perl -MCPAN -e "install Time:HiRes"

echo "creating nagios user and group"
useradd nagios
groupadd nagcmd
usermod -G nagcmd nagios
usermod -G nagcmd apache

NAGIOS=nagios-4.0.4
NRPE=nrpe-2.15
NAGIOSPLUGINS=nagios-plugins-2.0
PNP4NAGIOS=pnp4nagios-head

echo "Downloading ${NAGIOS}"
wget http://prdownloads.sourceforge.net/sourceforge/nagios/${NAGIOS}.tar.gz -P /tmp/ -q
echo "Downloading ${NAGIOSPLUGINS}"
wget http://nagios-plugins.org/download/${NAGIOSPLUGINS}.tar.gz -P /tmp/ -q
echo "Downloading ${PNP4NAGIOS}"
wget http://docs.pnp4nagios.org/_media/dwnld/${PNP4NAGIOS}.tar.gz -P /tmp/ -q
echo "Downloading ${NRPE}"
wget http://downloads.sourceforge.net/project/nagios/nrpe-2.x/nrpe-2.15/${NRPE}.tar.gz -P /tmp/ -q

echo "editig iptables"
cp /etc/sysconfig/iptables /etc/sysconfig/iptables.save.bak
iptables -I INPUT 5 -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
iptables -I INPUT 6 -m state --state NEW -m tcp -p tcp --dport 5666 -j ACCEPT
/etc/init.d/iptables save
service iptables restart

echo "disabling selinux otherwise nagios doesn’t work"
sed -c -i "s/SELINUX=enforcing/SELINUX=disabled /" /etc/selinux/config
echo 0 > /selinux/enforce

echo "installing nagios"
tar xvzf /tmp/${NAGIOS}.tar.gz -C /tmp/
cd /tmp/${NAGIOS}
./configure --prefix=/opt/nagios --with-command-group=nagcmd
make all
make install
make install-init
make install-commandmode
make install-config
make install-webconf
HTPASS=nagiosadmin
htpasswd -cb /opt/nagios/etc/htpasswd.users nagiosadmin $HTPASS

echo "installing nagios plugins"
tar xvzf /tmp/${NAGIOSPLUGINS}.tar.gz -C /tmp/
cd /tmp/${NAGIOSPLUGINS}
./configure --prefix=/opt/nagios --with-nagios-user=nagios --with-nagios-group=nagios
make
make install

# depends on openssl-devel
# but it was installed earlier in this script
echo "instaling nrpe"
tar xvzf /tmp/${NRPE}.tar.gz -C /tmp/
cd /tmp/${NPRE}
./configure --prefix=/opt/nagios
make all
make install

echo "verifying nagios default configuration"
/opt/nagios/bin/nagios -v /opt/nagios/etc/nagios.cfg | grep "Total"

# depends on rrdtool rrdtool-perl php-gd
# but it was installed earlier in this script
echo "installing pnp4nagios"
tar xvzf /tmp/${PNP4NAGIOS}.tar.gz
cd /tmp/${PNP4NAGIOS}
./configure --prefix=/opt/pnp4nagios
make all
make fullinstall

# need \\ infront of \t otherwise it gets interpreted as a tab
echo "configuring pnp4nagios"
NAGPATH=/opt/nagios/
NAGCFGPATH=${NAGPATH}/etc/nagios.cfg
sed -c -i "s/process_performance_data=.*/process_performance_data=1/" ${NAGCFGPATH}
sed -c -i "s/^#host_perfdata_file=.*/host_perfdata_file=\/opt\/pnp4nagios\/var\/host-perfdata /" ${NAGCFGPATH}
sed -c -i "s/^#service_perfdata_file=.*/service_perfdata_file=\/opt\/pnp4nagios\/var\/service-perfdata /" ${NAGCFGPATH}
sed -c -i "s/^#host_perfdata_file_template=.*/host_perfdata_file_template=DATATYPE::HOSTPERFDATA\\\tTIMET::\$TIMET\$\\\tHOSTNAME::\$HOSTNAME\$\\\tHOSTPERFDATA::\$HOSTPERFDATA\$\\\tHOSTCHECKCOMMAND::\$HOSTCHECKCOMMAND\$\\\tHOSTSTATE::\$HOSTSTATE\$\\\tHOSTSTATETYPE::\$HOSTSTATETYPE\$\\\tHOSTOUTPUT::\$HOSTOUTPUT\$ /" ${NAGCFGPATH}
sed -c -i "s/^#service_perfdata_file_template=.*/service_perfdata_file_template=DATATYPE::SERVICEPERFDATA\\tTIMET::\$TIMET\$\\\tHOSTNAME::\$HOSTNAME\$\\\tSERVICEDESC::\$SERVICEDESC\$\\\tSERVICEPERFDATA::\$SERVICEPERFDATA\$\\\tSERVICECHECKCOMMAND::\$SERVICECHECKCOMMAND\$\\\tHOSTSTATE::\$HOSTSTATE\$\\\tHOSTSTATETYPE::\$HOSTSTATETYPE\$\\\tSERVICESTATE::\$SERVICESTATE\$\\\tSERVICESTATETYPE::\$SERVICESTATETYPE\$\\\tSERVICEOUTPUT::\$SERVICEOUTPUT\$ /" ${NAGCFGPATH}
sed -c -i "s/^#host_perfdata_file_mode=.*/host_perfdata_file_mode=a /" ${NAGCFGPATH}
sed -c -i "s/^#service_perf_data_file_mode=.*/service_perfdata_file_mode=a /" ${NAGCFGPATH}
sed -c -i "s/^#host_perfdata_file_processing_interval=.*/host_perfdata_file_processing_interval=60 /" ${NAGCFGPATH}
sed -c -i "s/^#service_perfdata_file_processing_interval=.*/service_perfdata_file_processing_interval=60 /" ${NAGCFGPATH}
sed -c -i "s/^#host_perfdata_file_processing_command=.*/host_perfdata_file_processing_command=process-host-perfdata-file /" ${NAGCFGPATH}
sed -c -i "s/^#service_perfdata_file_processing_command=.*/service_perfdata_file_processing_command=process-service-perfdata-file /" ${NAGCFGPATH}
sed -c -i "s/AuthUserFile \/usr\/local\/nagios\/etc\/htpasswd.users/AuthUserFile \/opt\/nagios\/etc\/htpasswd.users /" /etc/httpd/conf.d/pnp4nagios.conf
sed -c -i "s/.*Name of host.*/\tuse\t\t linux-server,host-pnp\t; Name of host template /" /opt/nagios/etc/objects/localhost.cfg
cat << EOF >> /opt/nagios/etc/objects/commands.cfg

# Performance data file processing commands
define command{
	command_name    process-service-perfdata-file
	command_line    /opt/pnp4nagios/libexec/process_perfdata.pl --bulk=/opt/pnp4nagios/var/service-perfdata
	}

define command{
	command_name    process-host-perfdata-file
	command_line    /opt/pnp4nagios/libexec/process_perfdata.pl --bulk=/opt/pnp4nagios/var/host-perfdata
	}

EOF

# need quotes around EOF otherwise $HOSTNAME will get interpreted
cat << 'EOF' >> /opt/nagios/etc/objects/templates.cfg

# enable extended info in Nagios so that links to the graphs are created for each applicable host and service
define host{
	name            host-pnp
	action_url      /pnp4nagios/index.php/graph?host=$HOSTNAME$&srv=_HOST_
	register        0
	}

define service{
	name            srv-pnp
	action_url      /pnp4nagios/index.php/graph?host=$HOSTNAME$&srv=$SERVICEDESC$
	register        0
}

EOF

echo "verifying nagios default configuration"
/opt/nagios/bin/nagios -v /opt/nagios/etc/nagios.cfg | grep "Total"

echo "renaming install.php script from pnp4nagios directory"
mv /opt/pnp4nagios/share/install.php /opt/pnp4nagios/share/install.php.bak

echo "lets just put something in /var/www/html/"
echo "Hello LASP!" > /var/www/html/index.html

service httpd restart
service nagios restart

echo "to double check things work visit:"
echo "http://localhost/nagios/"
echo "and"
echo "http://localhost/pnp4nagios/"
echo "the password for each page is: nagiosadmin"



