#!/usr/bin/expect -f
set timeout 20
spawn ./run2.sh
expect "*key*" { send "Par0v03ik\r" }
expect "*assword*" { send "Par0v03ik\r" }
expect "*assword*" { send "Par0v03ik\r" }
interact
