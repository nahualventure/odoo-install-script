#!/bin/bash
################################################################################
# Script for installing Odoo on Ubuntu 14.04, 15.04, 16.04 and 18.04 (could be used for other version too)
# Author: Oscar Gil
#-------------------------------------------------------------------------------
# This script will install Odoo on your Ubuntu 16.04 server. It can install multiple Odoo instances
# in one Ubuntu because of the different xmlrpc_ports
#-------------------------------------------------------------------------------
# Make a new file:
# sudo nano odoo-install.sh
# Place this content in it and then make the file executable:
# sudo chmod +x odoo-install.sh
# Execute the script to install Odoo:
# ./install
################################################################################

## instance parameters
PRODUCTION="True"
INSTALL_POSTGRESQL="False"
CREATE_POSTGRESQL_USER="False"
INSTALL_VIRTUALENVWRAPPER="False"
CREATE_GITCONFIG="False"
INSTANCE_USER="ubuntu"

## fixed parameters
# odoo
OE_USER="odoo"
OE_HOME="/home/$INSTANCE_USER"

# Directory
OE_SRC_FOLDER=""
DIR_ODOO="$OE_HOME$OE_SRC_FOLDER/odoo"
DIR_ENT="$OE_HOME$OE_SRC_FOLDER/enterprise"
DIR_ADD="$OE_HOME$OE_SRC_FOLDER/odoo-addons"
DIR_ADDX="$OE_HOME$OE_SRC_FOLDER/odoo-addons-external"

OE_HOME_LOG="$OE_HOME/${OE_USER}-logs"
OE_INSTANCE="$OE_USER"
# The default port where this Odoo instance will run under (provided you use the command -c in the terminal)
# Set to true if you want to install it, false if you don't need it or have it already installed.
INSTALL_WKHTMLTOPDF="True"
# Set the default Odoo port (you still have to use -c /etc/odoo-server.conf for example to use this.)
OE_PORT="8069"
OE_LONGP_PORT="8072"
OE_SMTP_PORT="25"
# Choose the Odoo version which you want to install. For example: 12.0, 11.0, 10.0 or saas-18. When using 'master' the master version will be installed.
# IMPORTANT! This script contains extra libraries that are specifically needed for Odoo 12.0
OE_VERSION="12.0"
# Set this to True if you want to install the Odoo enterprise version!
IS_ENTERPRISE="True"
# Workers config
OE_WORKERS="4"
OE_CRON_WORKERS="1"
# set the superadmin password
OE_SUPERADMIN="odoo123"
OE_CONFIG=".odoorc"
OE_INIT=".init-odoo"
OE_RUN_SCRIPT="odoo-base-run"
# Database params:
DB_VERSION="10"
DB_HOST="False"
DB_PASS="odoo123"
DB_TEMPLATE="template1"
DB_USER="odoo"
# Sentry params:
SENTRY="False"
ST_DSN=""


##
###  WKHTMLTOPDF download links
## === Ubuntu Trusty x64 & x32 === (for other distributions please replace these two links,
## in order to have correct version of wkhtmltox installed, for a danger note refer to
## https://www.odoo.com/documentation/8.0/setup/install.html#deb ):
WKHTMLTOX_X64=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.trusty_amd64.deb
WKHTMLTOX_X32=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.trusty_i386.deb

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Update Server ----"
# universe package is for Ubuntu 18.x
sudo add-apt-repository universe
# libpng12-0 dependency for wkhtmltopdf
sudo add-apt-repository "deb http://mirrors.kernel.org/ubuntu/ xenial main"
sudo apt-get update
sudo apt-get upgrade -y

if [ $PRODUCTION = "True" ]; then
  #--------------------------------------------------
  # Set Locale Settings
  #--------------------------------------------------
  export LC_ALL=C
fi

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
if [ $INSTALL_POSTGRESQL = "True" ]; then
  echo -e "\n---- Install PostgreSQL Server ----"
  sudo echo 'deb http://apt.postgresql.org/pub/repos/apt/ bionic-pgdg main' >> /etc/apt/sources.list.d/pgdg.list
  sudo wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add
  sudo apt-get update -y
  sudo apt-get install postgresql-$DB_VERSION -y
fi

if [ $CREATE_POSTGRESQL_USER = "True" ]; then
  echo -e "\n---- Creating the ODOO PostgreSQL User  ----"
  sudo su - postgres -c "psql -c \"CREATE USER $DB_USER WITH PASSWORD '$DB_PASS' CREATEDB;\""
  echo -e "\n---- Adding new line to pg_hba.conf ----"
  echo "local	all		$DB_USER					trust" | sudo tee --append /etc/postgresql/${DB_VERSION}/main/pg_hba.conf
fi

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n--- Installing Python 3 + pip3 --"
sudo apt-get install git python3 python3-pip build-essential wget python3-dev python3-venv python3-wheel libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools node-less libpng12-0 gdebi -y

REQUIREMENTS="-r https://github.com/odoo/odoo/raw/${OE_VERSION}/requirements.txt"
# Packages for custom modules
CUSTOM_REQUIREMENTS="xlsxwriter pysftp"

echo -e "\n---- Setting up virtualenv ----"
if [ $INSTALL_VIRTUALENVWRAPPER = "True" ]; then
  sudo pip3 install virtualenvwrapper
  export VIRTUALENV_PYTHON=/usr/bin/python3
  export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python3
  export WORKON_HOME=~/.virtualenvs
  mkdir -p $WORKON_HOME
  source /usr/local/bin/virtualenvwrapper.sh
  sudo mkvirtualenv $OE_USER
  workon $OE_USER

  echo -e "\n---- Install python packages/requirements ----"
  pip3 install $REQUIREMENTS
  pip3 install $CUSTOM_REQUIREMENTS
else
  echo -e "\n---- Install python packages/requirements ----"
  sudo pip3 install $REQUIREMENTS
  sudo pip3 install $CUSTOM_REQUIREMENTS
fi

if [ $CREATE_GITCONFIG = "True" ]; then
  git config --global credential.helper wincred
fi

echo -e "\n---- Install python packages/requirements ----"
sudo pip3 install -r https://github.com/odoo/odoo/raw/${OE_VERSION}/requirements.txt

echo -e "\n---- Installing nodeJS NPM and rtlcss for LTR support ----"
sudo apt-get install nodejs npm
sudo npm install -g rtlcss

#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
  echo -e "\n---- Install wkhtml and place shortcuts on correct place for ODOO 12 ----"
  #pick up correct one from x64 & x32 versions:
  if [ "`getconf LONG_BIT`" == "64" ];then
      _url=$WKHTMLTOX_X64
  else
      _url=$WKHTMLTOX_X32
  fi
  sudo wget $_url
  sudo gdebi --n `basename $_url`
  sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin
  sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin
else
  echo "Wkhtmltopdf isn't installed due to the choice of the user!"
fi

if [ $PRODUCTION = "True" ]; then
  echo -e "\n---- Create Log directory ----"
  sudo mkdir $OE_HOME_LOG/
fi

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n==== Installing ODOO Server ===="
sudo su $OE_USER -c "mkdir $DIR_ODOO"
sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $DIR_ODOO

##--------------------------------------------------
## Install Dependencies
##--------------------------------------------------
#echo -e "\\n--- Installing Python 3 + pip3 --"
#sudo apt-get install python3 python3-pip -y
#
#echo -e "\\n---- Install tool packages ----"
#sudo apt-get install wget git bzr python-pip gdebi-core -y
#
#echo -e "\\n---- Install python packages ----"
#sudo apt-get install python-pypdf2 python-dateutil python-feedparser python-ldap python-libxslt1 python-lxml python-mako python-openid python-psycopg2 python-pybabel python-pychart python-pydot python-pyparsing python-reportlab python-simplejson python-tz python-vatnumber python-vobject python-webdav python-werkzeug python-xlwt python-yaml python-zsi python-docutils python-psutil python-mock python-unittest2 python-jinja2 python-pypdf python-decorator python-requests python-passlib python-pil -y
#
#echo -e "\\n---- Setting up virtualenv ----"
#sudo pip3 install virtualenvwrapper
#export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python3
#source /usr/local/bin/virtualenvwrapper.sh
#sudo mkvirtualenv $OE_INSTANCE
#
#
#sudo pip3 install --upgrade pip
#sudo pip3 install pypdf2 Babel passlib Werkzeug decorator python-dateutil pyyaml psycopg2 psycopg2-binary psutil html2text docutils lxml pillow reportlab ninja2 requests gdata XlsxWriter vobject python-openid pyparsing pydot mock mako Jinja2 ebaysdk feedparser xlwt psycogreen suds-jurko pytz pyusb greenlet xlrd gevent
## Packages for custom modules
#sudo pip3 install xlsxwriter zeep pysftp
#
#echo -e "\\n---- Install python libraries ----"
## This is for compatibility with Ubuntu 16.04. Will work on 14.04, 15.04 and 16.04
#sudo apt-get install python3-suds -y
#
#echo -e "\\n--- Install other required packages"
#sudo apt-get install node-clean-css -y
#sudo apt-get install node-less -y
#sudo apt-get install python-gevent -y

if [ $IS_ENTERPRISE = "True" ]; then
  # Odoo Enterprise install!
  echo -e "\n--- Create symlink for node"
  sudo ln -s /usr/bin/nodejs /usr/bin/node

  sudo su $OE_USER -c "mkdir $DIR_ENT"
  sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise $DIR_ENT

  echo -e "\n---- Added Enterprise code under $DIR_ENT ----"
  echo -e "\n---- Installing Enterprise specific libraries ----"
  sudo pip3 install num2words ofxparse
  sudo npm install -g less
  sudo npm install -g less-plugin-clean-css
fi

echo -e "\n---- Cloning odoo-addons repository"
sudo su $OE_USER -c "mkdir $DIR_ADD"
git clone --branch $OE_VERSION https://www.github.com/nahualventure/odoo-addons $DIR_ADD

echo -e "\n---- Cloning odoo-addons-external repository"
sudo su $OE_USER -c "mkdir $DIR_ADDX"
git clone --branch $OE_VERSION https://www.github.com/nahualventure/odoo-addons $DIR_ADDX

echo -e "* Creating server config file"
cat <<EOF > ~/$OE_CONFIG
[options]
admin_passwd = $OE_SUPERADMIN
csv_internal_sep = ,
data_dir = $OE_HOME/.local/share/Odoo
db_host = $DB_HOST
db_maxconn = 64
db_name = False
db_password = $DB_PASS
db_port = False
db_sslmode = prefer
db_template = $DB_TEMPLATE
db_user = $DB_USER
dbfilter =
demo = {}
email_from = False
geoip_database = /usr/share/GeoIP/GeoLite2-City.mmdb
http_enable = True
http_interface = 127.0.0.1
http_port = $OE_PORT
import_partial =
limit_memory_hard = 8684354560
limit_memory_soft = 8147483648
limit_request = 80192
limit_time_cpu = 18000
limit_time_real = 18000
limit_time_real_cron = -1
list_db = True
log_db = False
log_db_level = warning
log_handler = :INFO
log_level = info
logfile = $OE_HOME_LOG/odoo-server.log
logrotate = True
longpolling_port = $OE_LONGP_PORT
max_cron_threads = $OE_CRON_WORKERS
osv_memory_age_limit = 1.0
osv_memory_count_limit = False
pg_path = None
pidfile = False
proxy_mode = True
reportgz = False
server_wide_modules = web
smtp_password = False
smtp_port = $OE_SMTP_PORT
smtp_server = localhost
smtp_ssl = False
smtp_user = False
syslog = False
test_enable = False
test_file = False
test_tags = None
translate_modules = ['all']
unaccent = False
without_demo = False
workers = $OE_WORKERS
EOF

if [ $IS_ENTERPRISE = "True" ]; then
  printf "addons_path=$DIR_ADD,$DIR_ADDX,$DIR_ENT,$DIR_ODOO/addons\n" >> ~/${OE_CONFIG}
else
  printf "addons_path=$DIR_ADD,$DIR_ADDX,$DIR_ODOO/addons\n" >> ~/${OE_CONFIG}
fi

if [ $PRODUCTION = "True" ] && [ $SENTRY = "True" ]; then
  printf "sentry_dsn = $ST_DSN\n" >> ~/${OE_CONFIG}.conf
  printf "sentry_enabled = true\n" >> ~/${OE_CONFIG}.conf
  printf "sentry_logging_level = error\n" >> ~/${OE_CONFIG}.conf
  printf "sentry_exclude_loggers = werkzeug\n" >> ~/${OE_CONFIG}.conf
  printf "sentry_ignore_exceptions = odoo.exceptions.AccessDenied,odoo.exceptions.AccessError,odoo.exceptions.MissingError,odoo.exceptions.RedirectWarning,odoo.exceptions.UserError,odoo.exceptions.ValidationError,odoo.exceptions.Warning,odoo.exceptions.except_orm\n" >> ~/${OE_CONFIG}.conf
  printf "sentry_processors = raven.processors.SanitizePasswordsProcessor,odoo.addons.sentry.logutils.SanitizeOdooCookiesProcessor\n" >> ~/${OE_CONFIG}.conf
  printf "sentry_transport = threaded\n" >> ~/${OE_CONFIG}.conf
  printf "sentry_include_context = true\n" >> ~/${OE_CONFIG}.conf
  printf "sentry_environment = production\n" >> ~/${OE_CONFIG}.conf
  printf "sentry_auto_log_stacks = false\n" >> ~/${OE_CONFIG}.conf
  printf "sentry_odoo_dir = $OE_HOME/odoo/odoo/\n" >> ~/${OE_CONFIG}.conf
fi

sudo chown $INSTANCE_USER ~/${OE_CONFIG}
sudo chmod 640 ~/${OE_CONFIG}

#--------------------------------------------------
# Adding ODOO as a deamon (initscript)
#--------------------------------------------------

if [ $PRODUCTION = "True" ]; then
  echo -e "* Create init file"
  cat <<EOF > ~/$OE_INIT
#!/bin/sh
### BEGIN INIT INFO
# Provides: $OE_INIT
# Required-Start: \$remote_fs \$syslog
# Required-Stop: \$remote_fs \$syslog
# Should-Start: \$network
# Should-Stop: \$network
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Enterprise Business Applications
# Description: ODOO Business Applications
### END INIT INFO
PATH=/bin:/sbin:/usr/bin
DAEMON=$OE_HOME/odoo-bin
NAME=$OE_INIT
DESC=$OE_INIT
# Specify the user name (Default: odoo).
USER=$INSTANCE_USER
# Specify an alternate config file (Default: /etc/openerp-server.conf).
CONFIGFILE="/etc/${OE_CONFIG}.conf"
# pidfile
PIDFILE=/var/run/\${NAME}.pid
# Additional options that are passed to the Daemon.
DAEMON_OPTS="-c \$CONFIGFILE"
[ -x \$DAEMON ] || exit 0
[ -f \$CONFIGFILE ] || exit 0
checkpid() {
[ -f \$PIDFILE ] || return 1
pid=\`cat \$PIDFILE\`
[ -d /proc/\$pid ] && return 0
return 1
}
case "\${1}" in
start)
echo -n "Starting \${DESC}: "
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
stop)
echo -n "Stopping \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
echo "\${NAME}."
;;
restart|force-reload)
echo -n "Restarting \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
sleep 1
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
*)
N=/etc/init.d/\$NAME
echo "Usage: \$NAME {start|stop|restart|force-reload}" >&2
exit 1
;;
esac
exit 0
EOF

  echo -e "* Security Init File"
  sudo mv ~/$OE_INIT /etc/init.d/$OE_INIT
  sudo chmod 755 /etc/init.d/$OE_INIT
  sudo chown root: /etc/init.d/$OE_INIT

  echo -e "* Start ODOO on Startup"
  sudo update-rc.d $OE_INIT defaults

  echo -e "* Starting Odoo Service"
  sudo su root -c "/etc/init.d/$OE_INIT start"

  #NGINX configuration
  echo -e "\\n ---- Installing NGINX ----"
  sudo apt-get install nginx -y
  sudo ufw allow 'Nginx HTTP'
  echo -e "* Creating nginx configuration file"
  sudo touch /etc/nginx/sites-available/$OE_INSTANCE
  sudo cat << EOF > /etc/nginx/sites-available/$OE_INSTANCE
upstream backend-odoo {
  server 127.0.0.1:$OE_PORT;
}

upstream backend-odoo-im {
  server 127.0.0.1:$OE_LONGP_PORT;
}

server {
  # odoo log files
  access_log /var/log/nginx/odoo-access.log;
  error_log /var/log/nginx/odoo-error.log;

  # increase proxy buffer size
  proxy_buffers 16 128k;
  proxy_buffer_size 256k;

  # force timeouts if the backend dies
  proxy_next_upstream error timeout invalid_header http_500
  http_502 http_503;

  # enable data compression
  gzip on;
  gzip_min_length 1100;
  gzip_buffers 4 64k;
  gzip_types text/plain text/xml text/css text/less
  application/x-javascript application/xml application/json
  application/javascript;
  gzip_vary on;

  client_max_body_size 100M;

  location /longpolling {
    proxy_pass http://backend-odoo-im;
  }

  location / {
    proxy_pass http://backend-odoo;
    proxy_connect_timeout       18000;
    proxy_send_timeout          18000;
    proxy_read_timeout          18000;
    send_timeout                18000;
  }

  location ~* /web/static/ {
    # cache static data
    proxy_cache_valid 200 60m;
    proxy_buffering on;
    expires 864000;
    proxy_pass http://backend-odoo;
  }

}
EOF
  echo -e "Setting up symlink"
  sudo ln -s /etc/nginx/sites-available/$OE_INSTANCE /etc/nginx/sites-enabled
  echo -e "Initializing nginx..."
  sudo rm /etc/nginx/sites-enabled/default
  sudo systemctl restart nginx
fi

echo "-----------------------------------------------------------"
echo "Done! The Odoo server is up and running. Specifications:"
echo "Port: $OE_PORT"
echo "User PostgreSQL: $DB_USER"
echo "Code location: $OE_HOME"
echo "Odoo folder: $OE_HOME/odoo/"
echo "Enterprise folder: $OE_HOME/enterprise/"
echo "Addons folder: $OE_HOME/odoo-addons/"
echo "Addons external folder: $OE_HOME/odoo-addons/"
#echo "Start Odoo service: sudo service $OE_CONFIG start"
#echo "Stop Odoo service: sudo service $OE_CONFIG stop"
#echo "Restart Odoo service: sudo service $OE_CONFIG restart"
echo "-----------------------------------------------------------"