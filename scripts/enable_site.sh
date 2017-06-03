#!/bin/bash
sudo cp scripts/nginx_conf/blog /etc/nginx/vhosts.d/blog.conf
sudo service nginx restart
