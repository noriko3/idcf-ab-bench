#!/bin/bash

usage() {
    echo "Usage: $(basename ${0}) [url]"
}

prog=`echo $(basename ${0}) | sed -e "s/\.sh//g"`

if [ $# -eq 1 ]; then
    target_url="${1}"
else
    usage 1>&2
    exit 1
fi

# Config file check
if [ ! -r ~/.idcfrc ] || [ ! -r ${prog}.conf ]; then
    echo "Cannot read config file." 1>&2
    exit 1
fi

# Command check
if ! type -p jq > /dev/null; then
    echo "Command not found: jq" 1>&2
    exit 1
fi

. ${prog}.conf

mkdir -p ${HOME}/tmp/idcf-ab
DIR_DATE=`date +%m%d-%H%M`

work_dir=${HOME}/tmp/idcf-ab/${DIR_DATE}
mkdir -p ${work_dir}

echo "work_dir: "${work_dir}

vmids=()
ports=()

echo ${vmids[1]}
str=`date +%s`
start_port=`echo ${str:6:4}`

for i in `seq 1 ${count}`
do
    #echo ${i}
    #echo "expr ${start_port} + ${i}"
    port=`expr ${start_port} + ${i}`
    ports[${i}]=${port}
    vmname=idcf-ab-bench-${DIR_DATE}-${i}    
    outputfile=${work_dir}/vm-${i}.json
    cloudstack-api deployVirtualMachine \
        --serviceofferingid ${service_offering_id} \
        --templateid ${template_id} \
        --zoneid ${zone_id} \
        --keypair ${keypair} \
        --name ${vmname} > ${outputfile}
    
    vmid=`cat ${outputfile}| jq -r ".deployvirtualmachineresponse.id"`
    
    sleep 20
    vmids[${i}]=${vmid}
    
    cloudstack-api createPortForwardingRule \
        --ipaddressid ${ipaddress_id} \
        --protocol TCP \
        --privateport 22 \
        --publicport ${port} \
        --virtualmachineid ${vmid} >/dev/null
done

sleep 40

#for i in `seq 1 ${count}`
#do
#    echo "apt-get update;apt-get install apache2 -y" | ssh -oStrictHostKeyChecking=no -p ${ports[${i}]} -i ${HOME}/.ssh/${keypair} root@${ipaddress}
#    sleep 10
#done

for i in `seq 1 ${count}`
do
    #echo "ab -n ${request_number} -c ${client_number} '${target_url}' && exit" | ssh -oStrictHostKeyChecking=no -i ${HOME}/.ssh/${keypair} root@${ipaddress} > ${work_dir}/vm-${i}.log 2>/dev/null &
    echo "ab -s 60 -r -n ${request_number} -c ${client_number} '${target_url}' && exit" | ssh -oStrictHostKeyChecking=no -p ${ports[${i}]} -i ${HOME}/.ssh/${keypair} root@${ipaddress} > ${work_dir}/ab-${i}.log 2>${work_dir}/error-${i}.log &
done


echo "destroy command:"
for i in `seq 1 ${count}`
do
    echo " cloudstack-api destroyVirtualMachine --id ${vmids[$i]}"
done