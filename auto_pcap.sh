#!/bin/bash

# A script to start pcap capture & rotate
### set cronjob in /etc/crontab
### 1 00 * * * root bash /opt/script/auto_pcap.sh

#### configure these values #### 

HOST_NAME=srv15-mme-7
S1MME_IP=172.17.80.168
S11_IP=172.17.63.168
S6A_IP=127.0.0.1


### functions ###

check_transfer () {
RESULT=$?
if [ $RESULT != 0 ]; then
    echo "an error has occured during file transfer. Exiting script."
    exit 1;
fi
}

### calculating time

eval "$(date +'today=%F now=%s')"
midnight=$(date -d "$today 0" +%s)
difference=$(echo "$((now - midnight))")
secs_to_midnight=$(expr 86400 - $difference)


S1MME_IF=$(netstat -ie | grep -B1 "$S1MME_IP" | head -n1 | cut -d " " -f1 | cut -d ":" -f 1)
S11_IF=$(netstat -ie | grep -B1 "$S11_IP" | head -n1 | cut -d " " -f1 | cut -d ":" -f 1)
S6A_IF=$(netstat -ie | grep -B1 "$S6A_IP" | head -n1 | cut -d " " -f1 | cut -d ":" -f 1)


screen -S s1mme -d -m tcpdump -G $secs_to_midnight -W 1 -i $S1MME_IF -w /coredump/$HOST_NAME-s1mme-%Y-%m-%d_%H.%M.%S.pcap
screen -S s11 -d -m tcpdump -G $secs_to_midnight -W 1 -i $S11_IF -w /coredump/$HOST_NAME-s11-%Y-%m-%d_%H.%M.%S.pcap
screen -S S6a -d -m tcpdump -G $secs_to_midnight -W 1 -i $S6A_IF -w /coredump/$HOST_NAME-s6a-%Y-%m-%d_%H.%M.%S.pcap

#### Transfer files 
echo ""
echo "\n##### Starting transfer of older pcaps ... #####\n"
echo ""
find /coredump -maxdepth 1 -type f -mtime +1 -print | cut -d "/" -f 3 > ListOfFiles.txt

if ! [ -s ListOfFiles.txt ]
then
    echo "No new pcaps for transfer. Exiting script"
    echo ""
    rm ListOfFiles.txt
    exit 0
fi

echo ""
echo "\n##### Creating Archives #####\n"
echo ""

while read -r filename
do
    tar -C /coredump -czvf $filename.tar.gz $filename
    scp $filename.tar.gz root@172.17.124.11:/data/pcaps/$HOST_NAME
    check_transfer
    echo "Transfer of $filename.tar.gz completed succesfully. "
    rm /coredump/$filename
    echo "Removed file from /coredump/$filename "
    rm $filename.tar.gz
done < ListOfFiles.txt

echo "All pcap files have fully been transferred."
rm ListOfFiles.txt
