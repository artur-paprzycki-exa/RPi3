#!/bin/sh

sudo mkdir -pv /etc/rsyslog.d/keys/ca.d
# create disk assisted queue for rsyslog
sudo mkdir /var/spool/rsyslog/

cd /etc/rsyslog.d/keys/ca.d/
# Setup GeoTrust Certificate
wget -O geotrust_ca.crt https://www.geotrust.com/resources/root_certificates/certificates/GeoTrust_Primary_CA.pem
# Setup DigiCert
wget -O digicert_ca.der https://www.digicert.com/CACerts/DigiCertHighAssuranceEVRootCA.crt
openssl x509 -inform der -in digicert_ca.der -out digicert_ca.crt
# With rsyslog is possible concatenate two certs together
# Concatenate GeoTrust with DigiCert together
cat digicert_ca.crt geotrust_ca.crt > digicert_geotrust_cas.crt
perl -p -i -e "s/\r//g" digicert_geotrust_cas.crt

# create 22-sumo.conf for rsyslog

cat > /etc/rsyslog.d/22-sumo.conf <<\EOF
########################################################
###    Sumologic  syslogTemplate for Raspbian        ###
########################################################
# Setup disk assisted queues# Setup disk assisted queues
$WorkDirectory /var/spool/rsyslog # where to place spool files
$ActionQueueFileName fwdRule1     # unique name prefix for spool files
$ActionQueueMaxDiskSpace 10m       # 1gb space limit (use as much as possible)
$ActionQueueSaveOnShutdown on     # save messages to disk on shutdown
$ActionQueueType LinkedList       # run asynchronously
$ActionResumeRetryCount -1        # infinite retries if host is down

# RsyslogGnuTLS
$DefaultNetstreamDriverCAFile /etc/rsyslog.d/keys/ca.d/digicert_geotrust_cas.crt

template(name="SumoFormat" type="string" string="<%pri%>%protocol-version% %timestamp:::date-rfc3339% %HOSTNAME% %app-name% %procid% %msgid% [PLACE_SUMOLOGIC_COLLECTOR_TOKEN_HERE] %msg%\n
")

if $syslogtag == 'wifi_audit.sh:' then {

action(type="omfwd"
        protocol="tcp"
        target="syslog.collection.eu.sumologic.com"
        port="6514"
        template="SumoFormat"
        StreamDriver="gtls"
        StreamDriverMode="1"
        StreamDriverAuthMode="x509/name"
        StreamDriverPermittedPeers="syslog.collection.*.sumologic.com")
}
#################END CONFIG FILE #########################"
EOF

apt-get -y install rsyslog-gnutls ntp

# add 64k message limit to syslog after line 6
if ! grep -i "MaxMessageSize" /etc/rsyslog.conf &>/dev/null 
	then 
		sed -i '6a\$MaxMessageSize 64k' /etc/rsyslog.conf 
	fi

# restart syslog
/etc/init.d/rsyslog restart

# Setup time zone
echo "Europe/London" > /etc/timezone

# create wifi_scan.sh script in /home/pi user folder

cat > /home/pi/wifi_audit.sh << \EOF
#!/bin/bash
test -x /sbin/iwlist || exit 0
exec 1> >(logger --size 64k -t $(basename $0)) 2>&1

/sbin/iwlist wlan0 scan| awk -F '[ :]+' '/(Address|Freq|Qual)/{gsub(/^[ ]+/,"",$0); printf $0"," } /SSID/{print $3,$4}'

# gsub - removes spaces from output; $0 full string as result with matching word. To get reult after keyword use $1,$2...$6 etc. 
EOF

chmod +x /home/pi/wifi_audit.sh

# schedule wifi scan
if ! crontab -l | grep wifi_audit &>/dev/null
	then 
		(crontab -l && echo "@daily sudo /home/pi/wifi_audit.sh") | crontab - 
        else
                crontab -l | sed 's%@hourly%30 8 * * *%' | crontab -
	fi


# Add auto logout after 15 min.
apt-get install -y xautolock
if ! grep -i "xautolock" /home/pi/.config/lxsession/LXDE-pi/autostart &>/dev/null 
        then 
                sed -i '$ a\xautolock -time 15 -locker "sudo pkill -u pi" &' /home/pi/.config/lxsession/LXDE-pi/autostart
        fi