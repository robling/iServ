个人使用的服务器维护脚本
=======

所有的对外服务都尽可能使用镜像提供，使用Podman驱动

### 文件目录结构
```
$ ls -l
Backup
Config
Data
```

### 运行之前
``` Bash
# 设置密码（用户名为你的当前用户）
export PASSWD="YOUR PASSWORD"
```

### 备份数据
``` Bash
# 删除上一次备份的文件
sudo rm backup.tar.gz
# 导出数据库
sudo podman exec -it db mariadb-dump -u $USER --password=$PASSWD blog > ~/Data/dump.sql
# 打包文件
sudo tar cpzf backup.tar.gz Config/ Data/
# 按时间戳归档
sudo cp backup.tar.gz ~/Backup/backup_$(date +"%Y%m%d_%H%M%S").tar.gz
```

### From Existing Server：
``` Bash
scp {user_name}@{ip_adress}:~/backup.tar.gz ~/
tar xzpvf backup.tar.gz .
```

### 创建POD以及wordpress运行需要的镜像
``` Bash
# 先创建一个POD
sudo podman pod create --name web -p 18046:18046 -p 80:80 -p 443:443 

# 然后依次创建caddy:latest, mariadb:latest, redis:latest和wordpress:

sudo podman run --name caddy --pod web \
  --label "io.containers.autoupdate=image" \
  -v /home/$USER/Data/caddy_data:/data:z \
  -v /home/$USER/Config/Caddyfile:/etc/caddy/Caddyfile:z \
  -v /home/$USER/Data/wordpress:/var/www/html:z \
  -d docker.io/library/caddy

sudo podman run --name db --pod web \
  --label "io.containers.autoupdate=image" \
  -e MARIADB_USER=$USER \
  -e MARIADB_PASSWORD=$PASSWD \
  -e MARIADB_DATABASE=blog \
  -e MARIADB_ROOT_PASSWORD=$PASSWD \
  -v /home/$USER/Data/mariadb:/var/lib/mysql:Z \
  -v /home/$USER/Data/dump.sql:/docker-entrypoint-initdb.d/dump.sql:z \
  -d docker.io/library/mariadb

sudo podman run --name wordpress --pod web \
  --label "io.containers.autoupdate=image" \
  -e WORDPRESS_DB_HOST=127.0.0.1 \
  -e ALLOW_EMPTY_PASSWORD=yes \
  -e WORDPRESS_DB_USER=$USER \
  -e WORDPRESS_DB_PASSWORD=$PASSWD \
  -e WORDPRESS_DB_NAME=blog \
  -v /home/$USER/Data/wordpress:/var/www/html:z \
  -d docker.io/library/wordpress:fpm

sudo podman run --name redis --pod web \
  --label "io.containers.autoupdate=image" \
  -d docker.io/library/redis:latest
```

### 确认各项服务正常
```
# 确认镜像都运行起来了
sudo podman ps

# 再确认下wordpress本身是否可用
```

### 使用Systemd管理服务
```
# 切换到systemd配置文件目录
mkdir -p ~/Config/systemd && cd "$_"

# 生成systemd config
sudo podman generate systemd --new --files --name web

# 激活systemd服务
sudo cp * /etc/systemd/system
sudo systemctl daemon-reload
sudo systemctl start pod-web
```

### 更新镜像
```
# 手动更新镜像
sudo podman auto-update

# 自动更新
mkdir -p ~/Config/systemd && cd "$_"
wget https://raw.githubusercontent.com/robling/iServ/refs/heads/master/Config/podman-auto-update.service.in
wget https://raw.githubusercontent.com/robling/iServ/refs/heads/master/Config/podman-auto-update.timer
sudo cp * /etc/systemd/system
sudo systemctl daemon-reload
sudo systemctl enable podman-auto-update.service
sudo systemctl enable podman-auto-update.timer
```


