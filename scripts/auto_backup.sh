#!/bin/bash
backup_dir="/home/mio/backup"
#dropboxdir=


dir=${backup_dir}/`date +%Y-%m-%d`
mkdir -p ${dir}

# backup database
db_username=$1
db_password=$2
mysqldump -u ${db_username} --password=${db_password} blog > ${dir}/blog.sql

# backup www file
tar zcf ${dir}'/www.tar.gz' /home/mio/www

tar cvf ${dir}'.tar' ${dir}
rm -r ${dir}
