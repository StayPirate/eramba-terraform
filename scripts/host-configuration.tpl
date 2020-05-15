#!/bin/bash
### Clone eramba repository
cd /home/${op_user}
sudo -u ${op_user} git clone https://github.com/staypirate/eramba.git --branch enterprise --single-branch
cd eramba
sudo -u ${op_user} git submodule update --init --remote
_erambapath=$(pwd)

### Configure database access
sed -i "s/^\(\s*'password' => '\).*$/\1${db_password}',/" $${_erambapath}/database.php
sed -i "s/^\(\s*'login' => '\).*$/\1${db_username}',/" $${_erambapath}/database.php
sed -i "s/^\(\s*'database' => '\).*$/\1${db_database}',/" $${_erambapath}/database.php
sed -i "s/^\(\s*'host' => '\).*$/\1${db_address}',/" $${_erambapath}/database.php
chown 33:33 $${_erambapath}/database.php

### Configure Apache
mkdir -p $${_erambapath}/enterprise
aws s3 cp "s3://${s3_address}/${eramba_src}" $${_erambapath}/enterprise
chown ${op_user}:${op_user} $${_erambapath}/enterprise/${eramba_src}
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -subj '/CN=${eramba_domain}/O=Company_Here/C=DE' -keyout $${_erambapath}/certs/${eramba_domain}.key -out $${_erambapath}/certs/${eramba_domain}.cert

### Databse initialization
echo "create database ${db_database}" | mysql -h ${db_address} -u ${db_username} -p${db_password}
mkdir -p $${_erambapath}/tmp
tar zxf $${_erambapath}/enterprise/${eramba_src} -C $${_erambapath}/tmp >/dev/null 2>&1
sed -i -e 's/DEFINER=`root`@`localhost`//g' $${_erambapath}/tmp/eramba_v2/app/Config/db_schema/${db_schema_v}.sql
sed -i -e 's/DEFINER=`root`@`localhost`/DEFINER=`${db_username}`@`%`/g' $${_erambapath}/tmp/eramba_v2/app/Config/db_schema/${db_schema_v}.sql
echo "source $${_erambapath}/tmp/eramba_v2/app/Config/db_schema/${db_schema_v}.sql" | mysql -h ${db_address} -u ${db_username} -p${db_password} ${db_database}
rm -r $${_erambapath}/tmp

### Docker: build image and spin the container
systemctl daemon-reload
systemctl enable docker
systemctl start docker

docker build -t eramba-enterprise:local .

# Using the host network configuration to allow apache to reach out to the Amazon RDS
docker container run \
        --detach \
        --name eramba_web \
        -e ERAMBA_DOMAIN=${eramba_domain} \
        -v $${_erambapath}/database.php:/var/www/html/app/Config/database.php \
        -v $${_erambapath}/certs:/certs \
        --net host \
    eramba-enterprise:local

### Configure host OS
# Ensure ip_forward is set
echo "1" > /etc/sysctl.d/99-ipv4_forward.conf
sysctl -p
# Forward 80->8080 and 443->8443. Since apache runs as unprivileged user cannot bind on port<1024
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 443 -j REDIRECT --to-port 8443
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 80 -j REDIRECT --to-port 8080
iptables-save