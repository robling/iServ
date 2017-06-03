#!/bin/zsh

acme_sh="/home/mio/www/acme.sh/acme.sh"
basedir="/home/mio/www/letsencrypt"

${acme_sh} --issue -d spdf.me -w ${basedir}/wellknown
${acme_sh} --install-cert -d spdf.me \
	--key-file		${basedir}/spdf.me/privkey.pem \
	--fullchain-file	${basedir}/spdf.me/fullchain.pem \
	--reloadcmd		"service nginx force-reload"		

#sudo service nginx force-reload
