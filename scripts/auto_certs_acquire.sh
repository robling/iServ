#!/bin/zsh

acme_sh="/home/mio/www/acme.sh/acme.sh"
basedir="/home/mio/www/letsencrypt"

export DP_Id="API Token 的 ID"
export DP_Key="API Token"

${acme_sh} --issue --dns dns_dp -d spdf.me
${acme_sh} --install-cert -d spdf.me \
	--key-file		${basedir}/spdf.me/privkey.pem \
	--fullchain-file	${basedir}/spdf.me/fullchain.pem \
	--reloadcmd		"service nginx force-reload"		

#sudo service nginx force-reload
