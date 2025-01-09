个人使用的服务器维护脚本
=======

所有的对外服务都尽可能使用镜像提供，使用Podman驱动

数据文件：
`pwd`
  \Config
  \Data
  \Backup

### Before Running
``` Bash
export PASSWD="YOUR PASSWORD"
```

### Backup：
``` Bash
# 删除上一次备份的文件
sudo rm backup.tar.gz
# 导出数据库
sudo podman exec -it db mariadb-dump -u $USER --password=$PASSWD blog > ~/Data/dump.sql
# 打包文件
sudo tar cpzf backup.tar.gz Config/ Data/
# 按时间戳归档
cp backup.tar.gz ~/Backup/backup_$(date +"%Y%m%d_%H%M%S").tar.gz
```

### From Existing Server：
``` Bash
scp {user_name}@{ip_adress}:~/backup.tar.gz ~/
tar xzpvf backup.tar.gz .
```

### Construct Server
``` Bash
sudo podman pod create --name web -p 18046:18046 -p 80:80 -p 443:443 

sudo podman run --name caddy --pod web \
 -v /home/$USER/Data/caddy_data:/data:z \
 -v /home/$USER/Config/Caddyfile:/etc/caddy/Caddyfile:z \
 -v /home/$USER/Data/wordpress:/var/www/html:z \
 -d docker.io/library/caddy

sudo podman run --name db --pod web \
 -e MARIADB_USER=$USER \
 -e MARIADB_PASSWORD=$PASSWD \
 -e MARIADB_DATABASE=blog \
 -e MARIADB_ROOT_PASSWORD=$PASSWD \
 -v /home/$USER/Data/mariadb:/var/lib/mysql:Z \
 -v /home/$USER/Data/dump.sql:/docker-entrypoint-initdb.d/dump.sql:z \
 -d docker.io/library/mariadb

sudo podman run --name wordpress --pod web \
  -e WORDPRESS_DB_HOST=127.0.0.1 \
  -e ALLOW_EMPTY_PASSWORD=yes \
  -e WORDPRESS_DB_USER=$USER \
  -e WORDPRESS_DB_PASSWORD=$PASSWD \
  -e WORDPRESS_DB_NAME=blog \
  -v /home/$USER/Data/wordpress:/var/www/html:z \
  -d docker.io/library/wordpress:fpm

sudo podman run --name redis --pod web \
  -d docker.io/library/redis:latest

sudo podman generate kube web -f web_pod_kube.yaml
```

## For Redhat Linux


## For Debian Linux
