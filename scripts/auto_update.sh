#!/bin/bash
zypper -n dup --no-allow-vendor-change > /home/mio/iServ/log/auto_update.log

snapper cleanup number
