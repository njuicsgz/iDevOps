#!/bin/bash
export PATH=/sbin:/usr/sbin:/usr/local/sbin:/usr/local/bin:/usr/bin:/bin
export WORKDIR=$( cd ` dirname $0 ` && pwd )
cd "$WORKDIR" || exit 1

get_my_ip()
{
    my_ip=$(ip route get 1.0.0.0 | head -1 | cut -d' ' -f8)
    if [ ! -n "$my_ip" ]; then  
      my_ip=$(ifconfig eth0 | grep -oP 'inet addr:\K\S+')
      if [ ! -n "$my_ip" ]; then
            my_ip=$(hostname -I|cut -d' ' -f1)
      fi
    fi

    echo $my_ip
}

pre_check()
{
    # You MUST write k8s certification into this file
    KUBE_CERT=/pdata/docker/heat/.kube_cert
    if [ ! -f "$KUBE_CERT" ]; then
        echo "FATAL: $KUBE_CERT does not exist! exit."
        exit 1
    fi
}


install_mysql()
{
    echo 'pulling njuicsgz/mysql:5.5...'
    docker pull njuicsgz/mysql:5.5
    
    docker rm -f mysql
    mkdir -p /pdata/docker/mysql
    docker run --name mysql -h mysql -v /pdata/docker/mysql:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=Letmein123 -d njuicsgz/mysql:5.5
    echo 'sleep 5s to ensure mysql is ready'
    sleep 5 
    echo 'intalled mysql'
}

install_rabbitmq()
{
    echo 'pulling rabbitmq...'
    docker pull rabbitmq
    
    echo 'sleep 2s to ensure rabbitmq is ready'
    sleep 2 
    docker rm -f rabbitmq
    docker run -d --hostname rabbitmq --name rabbitmq -e RABBITMQ_DEFAULT_PASS=Letmein123 rabbitmq
    echo 'installed rabbitmq'
}

install_keystone()
{
    echo 'pulling njuicsgz/keystone:juno...'
    docker pull njuicsgz/keystone:juno
    
    docker rm -f keystone
    docker run -d \
        --link mysql:mysql\
        -e OS_TENANT_NAME=admin \
        -e OS_USERNAME=admin \
        -e OS_PASSWORD=ADMIN_PASS \
        -p 35357:35357\
        -p 5000:5000 \
        --name keystone -h keystone njuicsgz/keystone:juno
    echo 'sleep 60s to ensure keystone is ready'
    sleep 60
}

install_heat()
{
    echo 'pulling njuicsgz/heat:kilo-k8s-1.0.6...'
    docker pull njuicsgz/heat:kilo-k8s-1.0.6

    docker rm -f heat
    docker run \
      -p 8004:8004 \
      --link mysql:mysql\
      --link rabbitmq:rabbitmq\
      --link keystone:keystone\
      -v /var/log/heat:/var/log/heat \
      -v /pdata/docker/heat/:/root \
      --hostname heat \
      --name heat \
      -e KEYSTONE_HOST_IP=keystone \
      -e HOST_IP=heat \
      -e MYSQL_HOST_IP=mysql \
      -e MYSQL_USER=root \
      -e MYSQL_PASSWORD=Letmein123 \
      -e ADMIN_PASS=ADMIN_PASS \
      -e RABBIT_HOST_IP=rabbitmq \
      -e RABBIT_PASS=Letmein123 \
      -e HEAT_PASS=Letmein123 \
      -e HEAT_DBPASS=Letmein123 \
      -e HEAT_DOMAIN_PASS=Letmein123 \
      -e ETC_HOSTS="${hosts_conf}" \
      -d njuicsgz/heat:kilo-k8s-1.0.6
    echo 'sleep 5s to ensure heat is ready'
    sleep 5
}

install_heatclient()
{
    echo 'install heat over. Will install heat client...'
    apt-get update && apt-get install -y --force-yes python-heatclient

    echo "${my_ip} keystone" >> /etc/hosts
    
    echo "export OS_PASSWORD=ADMIN_PASS" >> ~/.bashrc
    echo "export OS_AUTH_URL=http://${my_ip}:35357/v2.0" >> ~/.bashrc
    echo "export OS_USERNAME=admin" >> ~/.bashrc
    echo "export OS_TENANT_NAME=admin" >> ~/.bashrc
    source ~/.bashrc
    
    heat resource-type-list | grep Google
    heat stack-list
}

hosts_conf=$1
my_ip=$(get_my_ip)

if [[ $# != 1 ]]; then
    echo 'usage: ./heat_restart.sh "172.30.10.185 dev.k8s.paas.ndp.com\n172.30.10.122 k8s.paas.ndp.com"'
    exit 1
fi


pre_check
install_mysql
install_rabbitmq
install_keystone
install_heat
#install_heatclient
