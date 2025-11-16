#!/bin/bash
################################################################################
# Odoo 17 Installation Script on Ubuntu 22.04 / 24.04 (KT24 Setup)
# Author: ChatGPT (based on your draft)
################################################################################

OE_USER="odoo17"
OE_HOME="/opt/odoo-development/$OE_USER"
OE_VERSION="17.0"
OE_PORT="8017"
OE_LONGPOLLING="9017"
OE_SUPERADMIN="master"
OE_CONFIG="/opt/odoo-development/$OE_USER/$OE_USER.conf"
OE_SERVICE="/etc/systemd/system/$OE_USER.service"

sudo mkdir -p $OE_HOME
sudo chown -R $OE_USER:$OE_USER $OE_HOME
sudo chmod -R 755 $OE_HOME

echo -e "\n============== Update Server ======================="
sudo apt update 
sudo apt upgrade -y
sudo apt autoremove -y

#--------------------------------------------------
# Install PostgreSQL
#--------------------------------------------------
echo -e "\n============== Install PostgreSQL =================="
sudo apt install -y postgresql
sudo systemctl enable --now postgresql

echo -e "\n============== Creating ODOO PostgreSQL User ================="
sudo su - postgres -c "createuser -s $OE_USER" || true

#--------------------------------------------------
# Install Python & system dependencies
#--------------------------------------------------
echo -e "\n============== Installing Python & Dependencies ================="
sudo apt install -y git python3 python3-dev python3-pip build-essential wget python3-venv python3-wheel python3-cffi \
libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools node-less libjpeg-dev gdebi libatlas-base-dev \
libblas-dev liblcms2-dev zlib1g-dev libjpeg8-dev libxrender1 software-properties-common libssl-dev \
libpq-dev libxml2-dev libxslt1-dev libffi-dev xfonts-75dpi xfonts-encodings xfonts-utils xfonts-base fontconfig

sudo pip3 install --upgrade pip setuptools wheel

#--------------------------------------------------
# Install Wkhtmltopdf (v0.12.5)
#--------------------------------------------------
echo -e "\n============== Installing wkhtmltopdf 0.12.5 ================="
cd /tmp
sudo wget https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.bionic_amd64.deb
sudo dpkg -i wkhtmltox_0.12.5-1.bionic_amd64.deb
sudo ln -sf /usr/local/bin/wkhtmltopdf /usr/bin
sudo ln -sf /usr/local/bin/wkhtmltoimage /usr/bin

#--------------------------------------------------
# Create Odoo system user
#--------------------------------------------------
echo -e "\n============== Creating ODOO system user ================="
sudo useradd -m -d $OE_HOME -U -r -s /bin/bash $OE_USER || true

#--------------------------------------------------
# Clone Odoo code
#--------------------------------------------------
echo -e "\n============== Cloning Odoo from GitHub ================="
sudo -u $OE_USER git clone --depth 1 --branch $OE_VERSION https://github.com/symlextechnologies/kt24_test.git $OE_HOME/$OE_USER

#--------------------------------------------------
# Install Python virtual environment
#--------------------------------------------------
echo -e "\n============== Setting up Python venv ================="
sudo apt install -y python3.12 python3.12-venv python3.12-dev

sudo -u $OE_USER bash <<EOF
cd $OE_HOME
python3.12 -m venv ${OE_USER}-venv
source ${OE_USER}-venv/bin/activate
pip install --upgrade pip wheel
pip install -r $OE_USER/requirements.txt
deactivate
EOF

#--------------------------------------------------
# Create Odoo configuration file
#--------------------------------------------------
echo -e "\n============== Creating Odoo Config ================="
sudo tee $OE_CONFIG <<EOF
[options]
admin_passwd = $OE_SUPERADMIN
db_host = False
db_port = False
db_user = $OE_USER
db_password = False
addons_path = $OE_HOME/$OE_USER/addons,$OE_HOME/$OE_USER/odoo/addons,$OE_HOME/$OE_USER/enterprise,$OE_HOME/$OE_USER/custom
logfile = /var/log/$OE_USER/$OE_USER.log
logrotate = True
xmlrpc_port = $OE_PORT
longpolling_port = $OE_LONGPOLLING
proxy_mode = True
EOF

sudo chown $OE_USER:$OE_USER $OE_CONFIG
sudo chmod 640 $OE_CONFIG

#--------------------------------------------------
# Setup log directory
#--------------------------------------------------
sudo mkdir -p /var/log/$OE_USER
sudo chown $OE_USER:$OE_USER /var/log/$OE_USER

#--------------------------------------------------
# Create systemd service
#--------------------------------------------------
echo -e "\n============== Creating systemd Service ================="
sudo tee $OE_SERVICE <<EOF
[Unit]
Description=Odoo17
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=$OE_USER
PermissionsStartOnly=true
User=$OE_USER
Group=$OE_USER
ExecStart=$OE_HOME/${OE_USER}-venv/bin/python3 $OE_HOME/$OE_USER/odoo-bin -c $OE_CONFIG
StandardOutput=journal+console
Restart=always

[Install]
WantedBy=multi-user.target
EOF

#--------------------------------------------------
# Start Odoo service
#--------------------------------------------------
sudo systemctl daemon-reload
sudo systemctl enable --now $OE_USER
sudo systemctl restart $OE_USER

echo "================================================================"
echo "Odoo $OE_VERSION installation finished!"
echo "Service: systemctl status $OE_USER"
echo "Config : $OE_CONFIG"
echo "Log    : /var/log/$OE_USER/$OE_USER.log"
echo "Running on: http://<your-server-ip>:$OE_PORT"
echo "================================================================"
