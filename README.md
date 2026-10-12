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
# 设置密码（用户名为你的当前用户），仅首次创建容器时使用
export PASSWD="YOUR PASSWORD"
```

### 备份数据
备份由 `Scripts/backup.sh` 完成（安装为 `/usr/local/sbin/iserv-backup`，需 root 运行）：
1. 在容器 `db` 内用 `mariadb-dump --single-transaction` 导出 `blog` 库到 `~/Data/dump.sql`（不使用 `-it`，定时任务中也能正常导出；导出为空/过小/不完整时直接报错退出）
2. 打包 `Config/` 和 `Data/`，原子写入 `~/Backup/backup_<YYYYmmdd_HHMMSS>[_<label>].tar.gz`
3. 同时把最新一份复制为 `~/backup.tar.gz`，兼容下面的 scp 恢复方式
4. 日志写入 journal：`sudo journalctl -t iserv-backup`

数据库账号密码保存在 `/etc/iserv/backup.env`（root 所有，权限 600，**不入库**），格式：
``` Bash
DB_USER='用户名'
DB_PASSWORD='密码'
DB_NAME=blog
DB_CONTAINER=db
```

安装：
``` Bash
sudo install -m 755 Scripts/backup.sh /usr/local/sbin/iserv-backup
sudo install -d -m 700 /etc/iserv
sudo sh -c 'umask 077; vi /etc/iserv/backup.env'
sudo cp Config/systemd/iserv-backup.service Config/systemd/iserv-backup.timer /etc/systemd/system
sudo systemctl daemon-reload
sudo systemctl enable --now iserv-backup.timer
```

- **每月自动备份**：`iserv-backup.timer` 每月 1 日 04:17（随机延迟 30 分钟内）执行，关机错过会在开机后补跑
- **重大变更前手动备份**：带上标签，例如 `sudo iserv-backup pre-upgrade`、`sudo iserv-backup pre-theme-switch`
- **保留策略**：无标签的月度备份保留最近 6 份，带标签的手动备份保留最近 5 份
- 查看下次执行时间：`systemctl list-timers iserv-backup.timer`

### 恢复数据
#### From Existing Server：
``` Bash
scp {user_name}@{ip_adress}:~/backup.tar.gz ~/
tar xzpvf backup.tar.gz .
# 或从本机归档恢复：tar xzpvf ~/Backup/backup_<时间戳>.tar.gz -C ~
# 新建 db 容器时会自动导入 Data/dump.sql；已有数据库可手动导入：
# sudo podman exec -i db mariadb -u $USER -p blog < ~/Data/dump.sql
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

### SSH 安全
- SSH 仅允许密钥登录，已禁用密码登录和 root 直接登录（配置见 `/etc/ssh/sshd_config.d/00-hardening.conf`）
- 已安装 fail2ban：同一 IP 10 分钟内失败 5 次封禁 1 小时
- POD 中已不再运行 notes-couchdb（CouchDB）和 cockpit

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


