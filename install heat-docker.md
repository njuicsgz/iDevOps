#1. install mysql(Master)
```
# docker pull mysql:5.5
mkdir -p /pdata/docker/mysql
docker run --name mysql -p 23306:3306 \
  -v /pdata/docker/mysql:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD=Letmein123 \
  -h mysql -d njuicsgz/mysql:5.5
```
#2. install keystone (Master，rerun该container会自动删除并重建DB)
```
docker run -d \
  --link mysql:mysql\
  -e OS_TENANT_NAME=admin \
  -e OS_USERNAME=admin \
  -e OS_PASSWORD=ADMIN_PASS \
  -p 35357:35357\
  -p 5000:5000 \
  --name keystone -h njuicsgz/keystone:juno
```
HOSTNAME Must the IP of OS_SERVICE_ENDPOINT which will provice service: 'http://${KEYSTONE_HOST}:35357/v2.0' to enable external access by host ip and port
# Verify
```
docker exec -t -i keystone bash
cd /root
source admin-openrc.sh
keystone user-list
```
如果需要外部访问，需要在keystone client的机子上：
```
# echo '10.2.240.12 keystone' >> /etc/hosts
```
PS：如果配置KEYSTONE_HOST=10.2.240.12，'http://${KEYSTONE_HOST}:35357/v2.0'，则该IP在container内部无法访问。
#3. install rabbitmq (与heat同在Master)
```
$ docker run -d --hostname rabbitmq --name rabbitmq -e RABBITMQ_DEFAULT_PASS=Letmein123 rabbitmq
```
#4. install heat
```
docker run \
  -p 8004:8004 \
  --link mysql:mysql\
  --link rabbitmq:rabbitmq\
  --link keystone:keystone\
  -v /var/log/heat:/var/log/heat \
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
  -d njuicsgz/heat:kilo
```
```
PS: 
1. MySQL可以使用单独可路由的外部DB，此时不在需要--link mysql:mysql
2. keystone不与Heat绑定在一个Host，但需要将keystone的WIP加入到/etc/hosts，因为从keystone返回的endpoint是用该域名
3. 创建之后，heat的endpoint将会是：--publicurl http://${KEYSTONE_HOST_IP}:8000/v1；所以访问该heat的客户端同样需要2的操作
```
