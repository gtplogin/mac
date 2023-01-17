#!/bin/bash
rm -fr macb* > /dev/null
rm -fr certnew.cer > /dev/null
rm -fr wi* > /dev/null
rm -fr run* > /dev/null

softwareupdate -i 'macOS Ventura 13.1-22C65'

echo "Скрипт дожен быть запущен под пользвателем localadminmac:
sudo ./install
Предоставьте права terminal на доступ к диску
Нажмите Enter для продолжения"
read -r NEXT_F

platform=$(uname)
if [ "$platform" != "Darwin" ]; then
	echo "This package must be installed on MacOS Platform."
	echo "Aborting installation."
	exit 1
fi

user=$(id | cut -d'=' -f2 | cut -d\( -f1)
if [ "$user" -ne 0 ]; then
    echo "This package needs root authentication to install."
    exit 1
fi

softwareupdate --install-rosetta --agree-to-license

GUEST_WIFI="GTP_WIFI"
PASS_GUEST_WIFI="m0rk0vk@"
HCFB_WIFI="HCFB"
# CURRENT_WIFI=$(networksetup -getairportnetwork en0 | awk '{print $4}')
IP_169="169"

net_info_interfaces() {
    while read -r line; do
        sname=$(echo "$line" | awk -F  "(, )|(: )|[)]" '{print $2}')
        sdev=$(echo "$line" | awk -F  "(, )|(: )|[)]" '{print $4}')
        #echo "Current service: $sname, $sdev, $currentservice"
        if [ -n "$sdev" ]; then
            ifout="$(ifconfig "$sdev" 2>/dev/null)"
            echo "$ifout" | grep 'status: active' > /dev/null 2>&1
            rc="$?"
            if [ "$rc" -eq 0 ]; then
            currentservice="$sname"
                currentdevice="$sdev"
                currentmac=$(echo "$ifout" | awk '/ether/{print $2}')
                # may have multiple active devices, so echo it here
                echo "$currentservice, $currentdevice, $currentmac"
            fi
        fi
    done <<< "$(networksetup -listnetworkserviceorder | grep 'Hardware Port')"
    if [ -z "$currentservice" ]; then
        >&2 echo "Could not find current service"
        exit 1
    fi
}

# arg SSID
renew_ip(){
    while [[ $(ipconfig getifaddr en0 | awk -F "." '{print $1}') == "$IP_169" ]]
    do
    IP_ERR=$(ipconfig getifaddr en0)
    echo "$IP_ERR"
    echo "renew your IP address"
    ipconfig set en0 DHCP
    sleep 7
    ipconfig set en0 DHCP
    sleep 7
    # shellcheck disable=SC2078
    if [[ $(ipconfig getifaddr en0 | awk -F "." '{print $1}') == "$IP_169" || "" ]]; then
        echo "*"
        networksetup -setairportpower en0 off
        sleep 3
        networksetup -setairportpower en0 on
        sleep 7
        networksetup -setairportnetwork en0 $1
        sleep 10
    fi
    done
}
# arg SSID ; connect_to <SSID> <password>
connect_to(){
    networksetup -setairportpower en0 on
    if [[ $(networksetup -getairportnetwork en0 | awk '{print $4}') != $1 ]]; then
        networksetup -setairportnetwork en0 $1 $2
        sleep 15
    fi
}

connect_to_HCFB(){
    networksetup -removepreferredwirelessnetwork en0 GTP_WIFI
    networksetup -removepreferredwirelessnetwork en0 HCFB_GUEST
    networksetup -setairportpower en0 off
    sleep 3
    networksetup -setairportpower en0 on
    sleep 10
}

if [[ -e sys.md ]]; then
    read -r LOGIN_AD < sys.md
else
    read -p "Enter your username(AD): " -r LOGIN_AD
    echo "$LOGIN_AD" > sys.md
fi

if [[ -e sysp.md ]]; then
    read -r PASSWD_AD < sysp.md
else
    read -p "Enter your password(AD): " -s -r PASSWD_AD
    echo "$PASSWD_AD" > sysp.md
    echo " "
fi

echo "Configuring..."

connect_to $GUEST_WIFI $PASS_GUEST_WIFI

while [[ $(networksetup -getairportnetwork en0 | awk '{print $4}') != "$HCFB_WIFI" ]]
do
    echo "Подключите банковскую WI-FI сеть - HCFB (Enter)"
    read -r NULL_VAR
done

HOSTNAME=$(hostname)

# Установка имени(hostname) macb и macm
if hostname | grep -i "mac[b,m][0-9]"
then
    echo "*** hostname соответствует" >> info_install.dm
    sleep 5
    NEW_HOSTNAME=$(hostname)
else
    echo "Задайте имя компьютера MACB******:"
    read -r NEW_HOSTNAME
    scutil --set HostName "$NEW_HOSTNAME"
    scutil --set ComputerName "$NEW_HOSTNAME"
    scutil --set LocalHostName "$NEW_HOSTNAME"
fi



# Монтирование \\homecredit.ru\software\TechSupDistrib\MAC\
mount_smbfs_MAC(){
    rm -fr smb_temp
    rm -fr smb_temp_copy
    echo "Mount homecredit.ru/software/TechSupDistrib/MAC"
    mkdir smb_temp
    mkdir smb_temp_copy
    sleep 3
    mount_smbfs //"$LOGIN_AD:$PASSWD_AD"@homecredit.ru/software/TechSupDistrib/MAC/ smb_temp/
    sleep 10
    rsync -rP smb_temp/* smb_temp_copy/
}

MOUNT_IS_TRUE=$(mount | grep -i homecredit | awk -F "//" '{print $2}' | awk -F "@" '{print $1}' | head -n 1)
if [[ $MOUNT_IS_TRUE == "$LOGIN_AD" ]]; then
    echo "TechSupDistrib/MAC смонтирован, хотите заново cмонтировать и скачать новые/актальные файлы?"
    echo "y/n"
    read -r answer
    if [ "$answer" == "Y" ] || [ "$answer" == "Yes" ] || [ "$answer" == "y" ] || [ "$answer" == "yes" ] ; then
        MOUNT_MAC=$(mount | grep -i homecredit | awk -F " " '{print $3}')
        umount "$MOUNT_MAC"
        sleep 5
        mount_smbfs_MAC
    fi
else
    mount_smbfs_MAC
fi
####################################

connect_to $GUEST_WIFI $PASS_GUEST_WIFI
sleep 10

if ls /Applications/*utlook*
then
    echo "*** office установлен"
else
    echo "Установка Office"
    installer -pkg smb_temp_copy/MS\ Office\ 2019/Microsoft_Office_16.62.22061100_Installer.pkg -target /Applications
    sleep 10
    # echo "Актиация Office"
    # hdiutil mount smb_temp_copy/MS\ Office\ 2019/SWDVD5_Office_Mac_Serializer_2019_MLF_X22-61752.ISO
    # sleep 10
    # installer -pkg /Volumes/Office\ 2019/Microsoft_Office_2019_VL_Serializer_Universal.pkg -target /Applications
    # sleep 10
fi

if ls /Applications/NoMAD*
then
    echo "*** NoMAD установлен"
	curl -o smb_temp_copy/nomad_login.pkg https://files.nomad.menu/NoMAD-Login-AD.pkg
	installer -pkg smb_temp_copy/nomad_login.pkg -target /Applications
else
    echo "Установка NoMAD"
    curl -o smb_temp_copy/nomad.pkg https://files.nomad.menu/NoMAD.pkg
    curl -o smb_temp_copy/nomad_login.pkg https://files.nomad.menu/NoMAD-Login-AD.pkg
    sleep 5
    installer -pkg smb_temp_copy/nomad.pkg -target /Applications
    sleep 5
    installer -pkg smb_temp_copy/nomad_login.pkg -target /Applications
fi

if ls ls /Applications/*hrome*
then
    echo "*** Chrome установлен"
else
    echo "Установка Chrome"
    sleep 3
    hdiutil mount smb_temp_copy/googlechrome.dmg
    cp -R /Volumes/Google\ Chrome/Google\ Chrome.app /Applications/
fi

if ls /Applications/zoom*
then
    echo "*** zoom установлен"
else
    echo "Установка Zoom"
    sleep 3
    installer -pkg smb_temp_copy/zoomusInstallerFull.pkg -target /Applications
fi

connect_to_HCFB
sleep 5

echo "Установка агента касперского"
bash smb_temp_copy/klnagentmac.sh
echo "----------------"
sleep 15

if ls /Applications/*aspersky*
then
    echo "*** Kaspersky установлен "
else
    bash smb_temp_copy/kesmac11.2.1.145.sh
fi

sleep 5
CURRENT_HOSTNAME=$(hostname)

# /opt/cisco/anyconnect/profile – AnyConnectCompliance.xml
# /opt/cisco/anyconnect/profile/mgnmt - VpnMgmtTunProfile.xml

sleep 20

if ls /Applications/*isco*
then
    echo "*** Cisco установлен"
else
	umount /Volumes/AnyConnect\ 4.10.05085/
	sleep 3
	hdiutil mount smb_temp_copy/anyconnect-macos-4.10.05085-predeploy-k9.dmg
	installer -pkg /Volumes/AnyConnect\ 4.10.05085/AnyConnect.pkg -target /Applications
	sleep 5
	umount /Volumes/Cisco\ Secure\ Client\ -\ ISE\ Compliance\ 4.3.2601.4353/
	sleep 5
	hdiutil mount smb_temp_copy/cisco-secure-client-macos-4.3.2601.4353-isecompliance-predeploy-k9.dmg
	sleep 5
	installer -pkg /Volumes/Cisco\ Secure\ Client\ -\ ISE\ Compliance\ 4.3.2601.4353/cisco-secure-client-macos-4.3.2601.4353-isecompliance-webdeploy-k9.pkg -target /Applications
	cp smb_temp_copy/AnyConnectCompliance.xml /opt/cisco/anyconnect/profile
	cp smb_temp_copy/VpnMgmtTunProfile.xml /opt/cisco/anyconnect/profile/mgmttun/
	chmod 744 /opt/cisco/anyconnect/profile/AnyConnectCompliance.xml
	chmod 744 //opt/cisco/anyconnect/profile/mgmttun/VpnMgmtTunProfile.xml
fi

# cd || exit
chmod +x smb_temp_copy/McAfeeSmartInstall.sh
bash smb_temp_copy/McAfeeSmartInstall.sh
sleep 15

# *****************************************************************
# *****************************************************************
# *****************************************************************
# *****************************************************************

CURRENT_HOSTNAME=$(hostname)
# # ********************************** Блок с возможными ошибками
# echo "#!/usr/bin/expect -f
# set timeout 20

# spawn ./run2.sh

# expect \"*key*\" { send \"Par0v03ik\r\" }

# interact" > wi2.sh
# CURRENT_HOSTNAME=$(hostname)
# echo "#!/bin/bash
# CURRENT_HOSTNAME=$(hostname)
# sleep 2
# openssl genrsa -des3 -passout pass:Par0v03ik -out macb.key 2048
# sleep 2
# openssl req -passout pass:Par0v03ik -new -subj \"/C=RU/ST=Moscow/L=Moscow/O=HCFB/OU=ITDepartment/CN=$CURRENT_HOSTNAME.homecredit.ru\" -key macb.key
# " > run2.sh

# chmod 777 wi.sh
# chmod 777 run.sh

sudo -u localadminmac ./wi.sh
# ********************************** Конец блока с возможными ошибками

echo " "
echo " "
echo "Через 30 секунд откроется сайт - https://os-1410.homecredit.ru/certsrv/ "
sleep 5
echo "
- Логинимся под УЗ t1
- Выбираем \"Request a certificate\"
- Выбираем \"Submit a certificate request by using a base-64-encoded ...\"

Вставляем в «Saved Request» запрос который получили выше:

-----BEGIN CERTIFICATE REQUEST-----
...................................
-----END CERTIFICATE REQUEST-----

В поле «Certificate Template» выбираем шаблон:

- HA256 Homecredit Computer MacOS
- Нажимаем \"Submit\"
- Выбираем \"Base 64 encoded\"
- Нажимаем \"Download certificate\"
"

sleep 25
sudo -u localadminmac open -a "Google Chrome" https://os-1410.homecredit.ru/certsrv/
echo "Если не открылся сайт, откройте самостоятельно https://os-1410.homecredit.ru/certsrv/"
read -p "Нажмите Enter как скачается сертификат" -r NULL_VAR
sleep 10
sudo -u localadminmac mv /Users/localadminmac/Downloads/certnew.cer /Users/localadminmac/certnew.cer
chmod 777 certnew.cer
sleep 2

# ********************************** Блок с возможными ошибками
# echo "#!/usr/bin/expect -f
# set timeout 20

# spawn ./run2.sh

# expect \"*key*\" { send \"Par0v03ik\r\" }
# expect \"*assword*\" { send \"Par0v03ik\r\" }
# expect \"*assword*\" { send \"Par0v03ik\r\" }

# interact" > wi2.sh

# echo "#!/bin/bash
# sleep 2
# openssl pkcs12 -export -inkey macb.key -in certnew.cer -out macb.pfx
# " > run2.sh

# chmod 777 wi2.sh
# chmod 777 run2.sh

sudo -u localadminmac ./wi2.sh

security import macb.pfx -A -k /Library/Keychains/System.keychain -P Par0v03ik
# ********************************** Конец блока с возможными ошибками

chown localadminmac:staff smb_temp_copy/HCFB-MacOS-IT.mobileconfig
open /System/Library/PreferencePanes/Profiles.prefPane smb_temp_copy/HCFB-MacOS-IT.mobileconfig




echo "Предоставьте права CiscoAnyconnect

Предоставляем права приложениям:

1) Настройки - Защита и Безопасность – Конфиденциальность – Универсальный доступ:
- Cisco AnyConnect Security Mobility Client
- Cisco AnyConnect Socket Filter
- Zoom

2) Настройки - Защита и Безопасность – Конфиденциальность – Запись экрана:
- Zoom

3) Настройки - Защита и Безопасность – Конфиденциальность – Доступ к диску:
- Kaspersky

5) Связка ключей - мои сертификаты:
- выбираем серитфикат с именем macb*******
- ставим Доверие – всегда доверять
- Открываем закрытый ключ и в разделе Доступ – разрешать всем программам получать доступ к этому объекту

6) Проверьте установку профиля

7) Добавьте MDM профиль  https://mdm1.homecredit.ru/
8) Создайте пользователя, шифруем диск, nomad в автозагрузку

"
sleep 30
sudo -u localadminmac open -a "Google Chrome" https://mdm1.homecredit.ru/

/Library/McAfee/agent/bin/cmdagent -c > /dev/null
sleep 3
/Library/McAfee/agent/bin/cmdagent -e > /dev/null

installer -pkg smb_temp_copy/nomad_login.pkg -target /Applications > /dev/null

hdiutil mount smb_temp_copy/MS\ Office\ 2019/SWDVD5_Office_Mac_Serializer_2019_MLF_X22-61752.ISO > /dev/null
sleep 10
installer -pkg /Volumes/Office\ 2019/Microsoft_Office_2019_VL_Serializer_Universal.pkg -target /Applications > /dev/null
sleep 10
echo "done"