#!/usr/bin/expect -f
set timeout 20
spawn ./run.sh
expect "*key*" { send "Par0v03ik\r" }
expect "*key*" { send "Par0v03ik\r" }
expect "*key*" { send "Par0v03ik\r" }
expect "*key*" { send "Par0v03ik\r" }
interact
