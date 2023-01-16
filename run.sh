#!/bin/bash
CURRENT_HOSTNAME=$(hostname)
openssl genrsa -des3 -out macb.key 2048
openssl req -new -subj "/C=RU/ST=Moscow/L=Moscow/O=HCFB/OU=ITDepartment/CN=$CURRENT_HOSTNAME.homecredit.ru" -key macb.key
