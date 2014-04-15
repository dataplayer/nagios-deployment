#!/bin/bash

echo "installing needed software"
echo "you may need to hit the Enter key once or twice during this installation"

sleep 4
yum install -y httpd php gcc glibc glibc-common gd gd-devel make net-snmp wget perl-CPAN rrdtool rrdtool-perl php-gd openssl-devel git
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

NAGPATH=/opt/nagios
NAGETCPATH=${NAGPATH}/etc
NAGCFGPATH=${NAGPATH}/etc/nagios.cfg
NAGIOSVer=nagios-3.5.1
NAGIOS=nagios
NRPE=nrpe-2.15
NAGIOSPLUGINS=nagios-plugins-2.0
PNP4NAGIOS=pnp4nagios-head
NSCA=nsca-2.7.2
NCONF=nconf-1.3.0-0
NAGIOSQLVer=nagiosql_320

echo "Downloading ${NAGIOSVer}"
wget http://prdownloads.sourceforge.net/sourceforge/nagios/${NAGIOSVer}.tar.gz -P /tmp/ -q
echo "Downloading ${NAGIOSPLUGINS}"
wget http://nagios-plugins.org/download/${NAGIOSPLUGINS}.tar.gz -P /tmp/ -q
echo "Downloading ${PNP4NAGIOS}"
wget http://docs.pnp4nagios.org/_media/dwnld/${PNP4NAGIOS}.tar.gz -P /tmp/ -q
echo "Downloading ${NRPE}"
wget http://downloads.sourceforge.net/project/nagios/nrpe-2.x/nrpe-2.15/${NRPE}.tar.gz -P /tmp/ -q
echo "Downloading ${NSCA}"
wget http://prdownloads.sourceforge.net/sourceforge/nagios/${NSCA}.tar.gz -P /tmp/ -q
#echo "Downloading ${NCONF}"
#wget http://sourceforge.net/projects/nconf/files/nconf/1.3.0-0/${NCONF}.tgz -P /tmp/ -q
echo "Downloading ${NAGIOSQLVer}"
wget http://sourceforge.net/projects/nagiosql/files/nagiosql/NagiosQL%203.2.0/${NAGIOSQLVer}.tar.gz -P /tmp/ -q
echo "Downloading NagMap"
git clone https://github.com/hecko/nagmap.git /tmp/nagmap

echo "editig iptables"
cp /etc/sysconfig/iptables /etc/sysconfig/iptables.save.bak
iptables -I INPUT 5 -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
iptables -I INPUT 6 -m state --state NEW -m tcp -p tcp --dport 5666 -j ACCEPT
/etc/init.d/iptables save
service iptables restart

echo "disabling selinux otherwise nagios doesn’t work"
sed -c -i "s/SELINUX=enforcing/SELINUX=disabled /" /etc/selinux/config
echo 0 > /selinux/enforce

# Nagios 3.5.1
echo "installing nagios"
tar xvzf /tmp/${NAGIOSVer}.tar.gz -C /tmp/
cd /tmp/${NAGIOS}
./configure --prefix=/opt/nagios --with-command-group=nagcmd
make all
make install
make install-init
make install-commandmode
make install-config
make install-webconf
make install-exfoliation
HTPASS=nagiosadmin
htpasswd -cb ${NAGETCPATH}/htpasswd.users nagiosadmin ${HTPASS}

# add some missing config files, all will be empty
mkdir ${NAGETCPATH}/hosts
mkdir ${NAGETCPATH}/services
mv ${NAGETCPATH}/objects/* ${NAGETCPATH}/
mv ${NAGETCPATH}/localhost.cfg ${NAGETCPATH}/hosts
mv ${NAGETCPATH}/windows.cfg ${NAGETCPATH}/hosts
mv ${NAGETCPATH}/switch.cfg ${NAGETCPATH}/hosts
mv ${NAGETCPATH}/printer.cfg ${NAGETCPATH}/hosts
#mv ${NAGETCPATH}/objects/* ${NAGETCPATH}
rm -rf ${NAGETCPATH}/objects

# editing nagios.cfg so that it canf ind the config files generated by nagiosQL
sed -c -i "s/cfg_file=\/opt\/nagios\/etc\/objects\/commands.cfg/cfg_file=\/opt\/nagiosql\/commands.cfg /" ${NAGCFGPATH}
sed -c -i "s/cfg_file=\/opt\/nagios\/etc\/objects\/contacts.cfg/cfg_file=\/opt\/nagiosql\/contacts.cfg /" ${NAGCFGPATH}
sed -c -i "s/cfg_file=\/opt\/nagios\/etc\/objects\/timeperiods.cfg/cfg_file=\/opt\/nagiosql\/timeperiods.cfg /" ${NAGCFGPATH}
sed -c -i "s/cfg_file=\/opt\/nagios\/etc\/objects\/localhost.cfg/#cfg_file=\/opt\/nagiosql\/hosts\/localhost.cfg /" ${NAGCFGPATH}

# insert after the templates config
sed -c -i "/cfg_file=\/opt\/nagiosql\/timeperiods.cfg/a\cfg_file=\/opt\/nagiosql\/servicetemplates.cfg" ${NAGCFGPATH}
sed -c -i "/cfg_file=\/opt\/nagiosql\/timeperiods.cfg/a\cfg_file=\/opt\/nagiosql\/servicegroups.cfg" ${NAGCFGPATH}
sed -c -i "/cfg_file=\/opt\/nagiosql\/timeperiods.cfg/a\cfg_file=\/opt\/nagiosql\/serviceextinfo.cfg" ${NAGCFGPATH}
sed -c -i "/cfg_file=\/opt\/nagiosql\/timeperiods.cfg/a\cfg_file=\/opt\/nagiosql\/serviceescalations.cfg" ${NAGCFGPATH}
sed -c -i "/cfg_file=\/opt\/nagiosql\/timeperiods.cfg/a\cfg_file=\/opt\/nagiosql\/servicedependencies.cfg" ${NAGCFGPATH}
sed -c -i "/cfg_file=\/opt\/nagiosql\/timeperiods.cfg/a\cfg_file=\/opt\/nagiosql\/hosttemplates.cfg" ${NAGCFGPATH}
sed -c -i "/cfg_file=\/opt\/nagiosql\/timeperiods.cfg/a\cfg_file=\/opt\/nagiosql\/hostgroups.cfg" ${NAGCFGPATH}
sed -c -i "/cfg_file=\/opt\/nagiosql\/timeperiods.cfg/a\cfg_file=\/opt\/nagiosql\/hostextinfo.cfg" ${NAGCFGPATH}
sed -c -i "/cfg_file=\/opt\/nagiosql\/timeperiods.cfg/a\cfg_file=\/opt\/nagiosql\/hostescalations.cfg" ${NAGCFGPATH}
sed -c -i "/cfg_file=\/opt\/nagiosql\/timeperiods.cfg/a\cfg_file=\/opt\/nagiosql\/hostdependencies.cfg" ${NAGCFGPATH}
sed -c -i "/cfg_file=\/opt\/nagiosql\/timeperiods.cfg/a\cfg_file=\/opt\/nagiosql\/contacttemplates.cfg" ${NAGCFGPATH}
sed -c -i "/cfg_file=\/opt\/nagiosql\/timeperiods.cfg/a\cfg_file=\/opt\/nagiosql\/contactgroups.cfg" ${NAGCFGPATH}
sed -c -i "/#cfg_dir=\/opt\/nagios\/etc\/routers/a\cfg_dir=\/opt\/nagiosql\/services" ${NAGCFGPATH}
sed -c -i "/#cfg_dir=\/opt\/nagios\/etc\/routers/a\cfg_dir=\/opt\/nagiosql\/hosts" ${NAGCFGPATH}
sed -c -i "s/command_file=.*/command_file=\/opt\/nagios\/var\/rw\/nagios.cmd /" ${NAGCFGPATH}
sed -c -i "s/locak_file=.*/lock_file=\/opt\/nagios\/var\/nagios.lock /" ${NAGCFGPATH}


# needed in order for nagiosql to read and write to these files via the web gui
chown -R nagios:nagcmd /opt/nagios
chown nagios:nagcmd /opt/nagios/etc/nagios.cfg
chown nagios:nagcmd /opt/nagios/etc/cgi.cfg
chown nagios:nagcmd /opt/nagios/var/rw/nagios.cfg
chown nagios:nagcmd /opt/nagios/bin/nagios

chmod 775 /opt/nagios
chmod 664 /opt/nagios/etc/nagios.cfg
chmod 664 /opt/nagios/etc/cgi.cfg
chmod 750 /opt/nagios/bin/nagios


# Nagios Plugins
echo "installing nagios plugins"
tar xvzf /tmp/${NAGIOSPLUGINS}.tar.gz -C /tmp/
cd /tmp/${NAGIOSPLUGINS}
./configure --prefix=/opt/nagios --with-nagios-user=nagios --with-nagios-group=nagios
make
make install

# Remote plugin execution
# depends on openssl-devel
# but it was installed earlier in this script
echo "instaling nrpe"
tar xvzf /tmp/${NRPE}.tar.gz -C /tmp/
cd /tmp/${NPRE}
./configure --prefix=/opt/nagios
make all
make install

echo "verifying nagios default configuration"
${NAGPATH}/bin/nagios -v ${NAGCFGPATH}/nagios.cfg | grep "Total"

# Graphing with pnp4nagios
# depends on rrdtool rrdtool-perl php-gd
# but it was installed earlier in this script
echo "installing pnp4nagios"
tar xvzf /tmp/${PNP4NAGIOS}.tar.gz
cd /tmp/${PNP4NAGIOS}
./configure --prefix=/opt/pnp4nagios
make all
make fullinstall

# Configuring pnp4nagios
# need \\ infront of \t otherwise it gets interpreted as a tab
echo "configuring pnp4nagios"
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
sed -c -i "s/.*Name of host.*/\tuse\t\t linux-server,host-pnp\t; Name of host template /" /opt/nagios/etc/hosts/localhost.cfg

cat << EOF >> ${NAGETCPATH}/commands.cfg

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
cat << 'EOF' >> ${NAGETCPATH}	/templates.cfg

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
echo "Hi!" > /var/www/html/index.html


echo "Installing NagiosQL"
yum install -y php-session php-mysql php-gettext php-filter php-ftp php-pear libssh2-devel php-devel mysql-server
printf "\n" | pecl install -f ssh2-beta
touch /etc/php.d/ssh2.ini
echo "extension=/usr/lib64/php/modules/ssh2.so" > /etc/php.d/ssh2.ini
sed -c -i "s/^;date.timezone =.*/date.timezone = MST /" /etc/php.ini
tar xvzf /tmp/${NAGIOSQLVer}.tar.gz -C /var/www/html/
mv /var/www/html/nagiosql32 /var/www/html/nagiosql
chown -R apache:apache /var/www/html/nagiosql

echo "Preparing NagiosQL Database"
service mysqld start
/usr/bin/mysqladmin -u root password root
Q1="CREATE DATABASE IF NOT EXISTS db_nagiosql_v32;"
Q2="GRANT ALL ON *.* to 'nagiosql_user'@'localhost' IDENTIFIED BY 'nagiosqluser';"
Q3="FLUSH PRIVILEGES;"
SQL="${Q1}${Q2}${Q3}"
mysql -uroot -proot -e "$SQL"

mkdir /opt/nagiosql
mkdir /opt/nagiosql/hosts
mkdir /opt/nagiosql/services
mkdir /opt/nagiosql/backup
mkdir /opt/nagiosql/backup/hosts
mkdir /opt/nagiosql/backup/services
chown -R apache:nagios /opt/nagiosql
chmod 6755 /opt/nagiosql
chmod 6755 /opt/nagiosql/hosts
chmod 6755 /opt/nagiosql/services
chmod 6755 /opt/nagiosql/backup
chmod 6755 /opt/nagiosql/backup/hosts
chmod 6755 /opt/nagiosql/backup/services


echo "Installing NagMap"
yum install -y php-mbstring
cp -R /tmp/nagmap /var/www/html/
sed -c -i "s/\$nagios_cfg_file =.*/\$nagios_cfg_file = \"\/opt\/nagios\/etc\/nagios.cgf\"; /" /var/www/html/nagmap/config.php
sed -c -i "s/\$nagios_status_dat_file =.*/\$nagios_status_dat_file = \"\/opt\/nagios\/var\/status.dat\"; /" /var/www/html/nagmap/config.php
chown -R apache:apache /var/www/html/nagmap
echo "need to edit config.php"


service httpd restart
service nagios restart
service mysqld restart


echo "To finish configuration visit nagiosql first!:"
echo "http://localhost/nagiosql"
echo "db username: nagiosql_user"
echo "db password: nagiosqluser"
echo "db root username: root"
echo "db root password: root"
echo "click all check boxes"
echo "change /etc/nagiosql to /opt/nagiosql"
echo "change /etc/nagios to /opt/nagios"
echo "then remove the following directory: /var/www/html/nagiosql/install"
echo "then log into NagiosQL using the db username and password above"
echo "after logging go to: Administration -> Config targets -> Function -> Modify"
echo "then set the following parameters:"
echo "--------------------------------------------------------"
echo "Configuration target: 	localhost"
echo "Description: 				Local installation"
echo "Server name: 				localhost"
echo "Method: 					Fileaccess"
echo "Base directory: 			/opt/nagiosql/"
echo "Host directory: 			/opt/nagiosql/hosts/"
echo "Service directory: 		/opt/nagiosql/services/"
echo "Backup directory: 		/opt/nagiosql/backup/"
echo "Host backup directory: 	/opt/nagiosql/backup/hosts"
echo "Service backup directory: /opt/nagiosql/backup/services/"
echo "Nagios base directory: 	/opt/nagios/etc/"
echo "Import directory: 		/opt/nagios/etc/"
echo "Nagios command file: 		/opt/nagios/var/rw/nagios.cmd"
echo "Nagios binary file: 		/opt/nagios/bin/nagios"
echo "Nagios process file: 		/opt/nagios/var/nagios.lock"
echo "Nagios config file: 		/opt/nagios/etc/nagios.cfg"
echo "--------------------------------------------------------"
echo "now go to Tools -> Nagios control and click the first thee DO IT buttons"
echo "then start nagios from the command line"
echo "then go back and click the last DO IT button"
echo "--------------------------------------------------------"
echo "to access nagios:"
echo "http://localhost/nagios"
echo "to access pnp4nagios"
echo "http://localhost/pnp4nagios"
echo "the password for each page is: nagiosadmin"
echo "visit http://localhost/nagpmap to find NagMap"




