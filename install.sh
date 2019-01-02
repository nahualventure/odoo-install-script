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
# ./odoo-install
################################################################################

##instance parameters
PRODUCTION="True"
INSTALL_POSTGRESQL="True"
CREATE_POSTGRESQL_USER="True"
INSTANCE_USER="ubuntu"

##fixed parameters
#odoo
OE_USER="odoo"
OE_HOME="/home/$INSTANCE_USER"
OE_HOME_LOG="$OE_HOME/${OE_USER}-logs"
OE_INSTANCE="$OE_USER"
#The default port where this Odoo instance will run under (provided you use the command -c in the terminal)
#Set to true if you want to install it, false if you don't need it or have it already installed.
INSTALL_WKHTMLTOPDF="True"
#Set the default Odoo port (you still have to use -c /etc/odoo-server.conf for example to use this.)
OE_PORT="8069"
OE_LONGP_PORT="8072"
OE_SMTP_PORT="25"
# Choose the Odoo version which you want to install. For example: 12.0, 11.0, 10.0 or saas-18. When using 'master' the master version will be installed.
# IMPORTANT! This script contains extra libraries that are specifically needed for Odoo 12.0
OE_VERSION="12.0"
# Set this to True if you want to install Odoo 12 Enterprise!
IS_ENTERPRISE="False"
#Workers config
OE_WORKERS="4"
OE_CRON_WORKERS="1"
#set the superadmin password
OE_SUPERADMIN="OodOskg7812!"
OE_CONFIG=".odoorc"
OE_RUN_SCRIPT="odoo-base-run"
# Database params:
DB_HOST="http://localhost:5432"
DB_PASS="odoo123"
DB_TEMPLATE="template1"
DB_USER="odoo"
# Sentry params:
SENTRY="True"
ST_DSN="https://b1431655be754af8adf9d24458e50b90:cf04912ff7fe45f985b1aafd4d59ed29@sentry.io/211274"


##
###  WKHTMLTOPDF download links
## === Ubuntu Trusty x64 & x32 === (for other distributions please replace these two links,
## in order to have correct version of wkhtmltox installed, for a danger note refer to 
## https://www.odoo.com/documentation/8.0/setup/install.html#deb ):
WKHTMLTOX_X64=https://downloads.wkhtmltopdf.org/0.12/0.12.1/wkhtmltox-0.12.1_linux-trusty-amd64.deb
WKHTMLTOX_X32=https://downloads.wkhtmltopdf.org/0.12/0.12.1/wkhtmltox-0.12.1_linux-trusty-i386.deb

if [ $PRODUCTION = "True" ]; then
    #--------------------------------------------------
    # Update Server
    #--------------------------------------------------
    echo -e "\\n---- Update Server ----"
    sudo apt-get update -y
    sudo apt-get upgrade -y

    #--------------------------------------------------
    # Set Locale Settings
    #--------------------------------------------------
    export LC_ALL=C
fi

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
if [ $INSTALL_POSTGRESQL = "True" ]; then
    echo -e "\\n---- Install PostgreSQL Server ----"
    echo 'deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main' >> /etc/apt/sources.list.d/pgdg.list
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add
    sudo apt-get update -y
    sudo apt-get install postgresql-10 -y
fi

if [ $CREATE_POSTGRESQL_USER = "True" ]; then
    echo -e "\\n---- Creating the ODOO PostgreSQL User  ----"
    sudo su - postgres -c "createuser -s $DB_USER" 2> /dev/null || true
    echo -e "\\n---- Adding new line to pg_hba.conf ----"
    echo "local	all		$DB_USER					trust" | sudo tee --append /etc/postgresql/10/main/pg_hba.conf
fi

#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
    echo -e "\\n---- Install wkhtml and place shortcuts on correct place for ODOO 11 ----"
    #pick up correct one from x64 & x32 versions:
    if [ "`getconf LONG_BIT`" == "64" ];then
        _url=$WKHTMLTOX_X64
    else
        _url=$WKHTMLTOX_X32
    fi
    sudo wget $_url
    sudo apt-get install gdebi-core -y
    sudo gdebi --n `basename $_url`
    sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin
    sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin
else
    echo "Wkhtmltopdf isn't installed due to the choice of the user!"
fi

if [ $PRODUCTION = "True" ]; then
    echo -e "\\n---- Create Log directory ----"
    sudo mkdir $OE_HOME_LOG/

    echo -e "\\n---- Create odoo-run script ----"
    cat <<EOF > ~/$OE_RUN_SCRIPT
#!/bin/bash

$OE_HOME/odoo/odoo-bin
EOF
    sudo chmod +x $OE_RUN_SCRIPT

    sudo mkdir $OE_HOME_LOG/
fi

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\\n==== Installing ODOO Server ===="
git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME/

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\\n--- Installing Python 3 + pip3 --"
sudo apt-get install python3 python3-pip -y

echo -e "\\n---- Install tool packages ----"
sudo apt-get install wget git bzr python-pip gdebi-core -y

echo -e "\\n---- Install python packages ----"
sudo apt-get install python-pypdf2 python-dateutil python-feedparser python-ldap python-libxslt1 python-lxml python-mako python-openid python-psycopg2 python-pybabel python-pychart python-pydot python-pyparsing python-reportlab python-simplejson python-tz python-vatnumber python-vobject python-webdav python-werkzeug python-xlwt python-yaml python-zsi python-docutils python-psutil python-mock python-unittest2 python-jinja2 python-pypdf python-decorator python-requests python-passlib python-pil -y

echo -e "\\n---- Setting up virtualenv ----"
sudo pip3 install virtualenvwrapper
export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python3
source /usr/local/bin/virtualenvwrapper.sh
sudo mkvirtualenv $OE_INSTANCE


sudo pip3 install --upgrade pip
sudo pip3 install pypdf2 Babel passlib Werkzeug decorator python-dateutil pyyaml psycopg2 psycopg2-binary psutil html2text docutils lxml pillow reportlab ninja2 requests gdata XlsxWriter vobject python-openid pyparsing pydot mock mako Jinja2 ebaysdk feedparser xlwt psycogreen suds-jurko pytz pyusb greenlet xlrd gevent
# Packages for custom modules
sudo pip3 install xlsxwriter zeep pysftp

echo -e "\\n---- Install python libraries ----"
# This is for compatibility with Ubuntu 16.04. Will work on 14.04, 15.04 and 16.04
sudo apt-get install python3-suds -y

echo -e "\\n--- Install other required packages"
sudo apt-get install node-clean-css -y
sudo apt-get install node-less -y
sudo apt-get install python-gevent -y

if [ $IS_ENTERPRISE = "True" ]; then
    echo -e "\\n==== Installing ODOO Enterprise ===="
    # Odoo Enterprise install!
    echo -e "\\n--- Create symlink for node"
    sudo ln -s /usr/bin/nodejs /usr/bin/node
    # sudo su $INSTANCE_USER -c "mkdir $OE_HOME/odoo-enterprise"

    GITHUB_RESPONSE=$(git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME" 2>&1)
    while [[ $GITHUB_RESPONSE == *"Authentication"* ]]; do
        echo "------------------------WARNING------------------------------"
        echo "Your authentication with Github has failed! Please try again."
        printf "In order to clone and install the Odoo enterprise version you \\nneed to be an offical Odoo partner and you need access to\\nhttp://github.com/odoo/enterprise.\\n"
        echo "TIP: Press ctrl+c to stop this script."
        echo "-------------------------------------------------------------"
        echo " "
        GITHUB_RESPONSE=$(git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME" 2>&1)
    done

    echo -e "\\n---- Added Enterprise code under $OE_HOME/enterprise ----"
    echo -e "\n---- Installing Enterprise specific libraries ----"
    sudo pip3 install num2words ofxparse
    sudo apt-get install nodejs npm -y
    sudo npm install -g less
    sudo npm install -g less-plugin-clean-css
fi

echo -e "\\n---- Cloning odoo-addons repository"
GITHUB_RESPONSE=$(git clone --branch $OE_VERSION https://www.github.com/nahualventure/odoo-addons "$OE_HOME" 2>&1)
while [[ $GITHUB_RESPONSE == *"Authentication"* ]]; do
    echo "------------------------WARNING------------------------------"
    echo "Your authentication with Github has failed! Please try again."
    printf "In order to clone and install the Odoo enterprise version you \\nneed to be an offical Odoo partner and you need access to\\nhttp://github.com/odoo/enterprise.\\n"
    echo "TIP: Press ctrl+c to stop this script."
    echo "-------------------------------------------------------------"
    echo " "
    GITHUB_RESPONSE=$(git clone --branch $OE_VERSION https://www.github.com/nahualventure/odoo-addons "$OE_HOME" 2>&1)
done

echo -e "\\n---- Cloning odoo-addons-external repository"
GITHUB_RESPONSE=$(git clone --branch $OE_VERSION https://www.github.com/nahualventure/odoo-addons "$OE_HOME" 2>&1)
while [[ $GITHUB_RESPONSE == *"Authentication"* ]]; do
    echo "------------------------WARNING------------------------------"
    echo "Your authentication with Github has failed! Please try again."
    printf "In order to clone and install the Odoo enterprise version you \\nneed to be an offical Odoo partner and you need access to\\nhttp://github.com/odoo/enterprise.\\n"
    echo "TIP: Press ctrl+c to stop this script."
    echo "-------------------------------------------------------------"
    echo " "
    GITHUB_RESPONSE=$(git clone --branch $OE_VERSION https://www.github.com/nahualventure/odoo-addons "$OE_HOME" 2>&1)
done

echo -e "* Creating server config file"
cat <<EOF > ~/$OE_CONFIG
[options]
addons_path = $OE_HOME/odoo-addons,$OE_HOME/odoo-addons-external,$OE_HOME/enterprise,$OE_HOME/odoo/addons
admin_passwd = $OE_SUPERADMIN
csv_internal_sep = ,
data_dir = $OE_HOME/.local/share/Odoo
db_host = $DB_HOST
db_maxconn = 64
db_name = False
db_password = $DB_PASS
db_port = False
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
test_commit = False
test_enable = False
test_file = False
test_report_directory = False
translate_modules = ['all']
unaccent = False
without_demo = False
workers = $OE_WORKERS
EOF

if [ $PRODUCTION = "True" ] && [ $SENTRY = "True" ]; then
    sudo su root -c "printf 'sentry_dsn = $ST_DSN\n' >> ~/${OE_CONFIG}.conf"
    sudo su root -c "printf 'sentry_enabled = true\n' >> ~/${OE_CONFIG}.conf"
    sudo su root -c "printf 'sentry_logging_level = error\n' >> ~/${OE_CONFIG}.conf"
    sudo su root -c "printf 'sentry_exclude_loggers = werkzeug\n' >> ~/${OE_CONFIG}.conf"
    sudo su root -c "printf 'sentry_ignore_exceptions = odoo.exceptions.AccessDenied,odoo.exceptions.AccessError,odoo.exceptions.MissingError,odoo.exceptions.RedirectWarning,odoo.exceptions.UserError,odoo.exceptions.ValidationError,odoo.exceptions.Warning,odoo.exceptions.except_orm\n' >> ~/${OE_CONFIG}.conf"
    sudo su root -c "printf 'sentry_processors = raven.processors.SanitizePasswordsProcessor,odoo.addons.sentry.logutils.SanitizeOdooCookiesProcessor\n' >> ~/${OE_CONFIG}.conf"
    sudo su root -c "printf 'sentry_transport = threaded\n' >> ~/${OE_CONFIG}.conf"
    sudo su root -c "printf 'sentry_include_context = true\n' >> ~/${OE_CONFIG}.conf"
    sudo su root -c "printf 'sentry_environment = production\n' >> ~/${OE_CONFIG}.conf"
    sudo su root -c "printf 'sentry_auto_log_stacks = false\n' >> ~/${OE_CONFIG}.conf"
    sudo su root -c "printf 'sentry_odoo_dir = $OE_HOME/odoo/odoo/\n' >> ~/${OE_CONFIG}.conf"
fi

sudo chown $INSTANCE_USER /etc/${OE_CONFIG}.conf
sudo chmod 640 /etc/${OE_CONFIG}.conf

#NGINX configuration
if [ $PRODUCTION = "True" ]; then
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
echo "Odoo Enterprise folder: $OE_HOME/enterprise/"
echo "Odoo Addons folder: $OE_HOME/odoo-addons/"
#echo "Start Odoo service: sudo service $OE_CONFIG start"
#echo "Stop Odoo service: sudo service $OE_CONFIG stop"
#echo "Restart Odoo service: sudo service $OE_CONFIG restart"
echo "-----------------------------------------------------------"