# RPi3

Project based on raspbian os to meet PCI DSS 3.2.1 req 11.1
The configure_pi script, configure raspberry pi into wifi scanning drone. 
Scrip installs necessary modules, creates and schedule to run wifi_audit.sh script. 
It also configures rsyslog to send result to Sumologic cloud syslog collector over TLS 1.2. 
Each detected SSID and acompanying info is send as separate message in syslog format. 
To configure pi as rough wifi network detection drone download cofigure_pi script 
to /home/pi folder and run with command 'sudo bash /home/pi/configure_pi.sh'
Note: Configure_pi script has hardcoded sumologic syslog collector token, 
pleas amend line #35 with your own token. Token is stored between [] square brackets.
