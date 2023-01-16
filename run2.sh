#!/bin/bash
sleep 2
openssl pkcs12 -export -inkey macb.key -in certnew.cer -out macb.pfx
