#! /bin/bash

# detect specific model of m1500
# the original m1500
# the new m1500 (the m1500b) uses E5-2609 CPUs
cpu_count=`grep "model name" /proc/cpuinfo | wc -l`
cpu_model=`grep -m1 "model name" /proc/cpuinfo | cut -f2 -d: | cut -c2-`
if [[ $cpu_count -eq 12 ]]; then
    is_m1500b=`echo $cpu_model | grep 'E5-2609' | wc -l`
    if [ $is_m1500b -gt 0 ]; then
        model='m1500b'
    else
        model='m1500'
    fi
fi

case $model in
    m1500)
        declare -a from=(eth2 eth3 eth4 eth5 eth6 eth7 eth8 eth9 eth0 eth1)
        declare -a   to=(eth0 eth1 eth2 eth3 eth4 eth5 eth6 eth7 eth8 eth9)
        ;;
    m1500b)
        declare -a from=(eth6 eth7 eth8 eth9 eth2 eth3 eth4 eth5 eth0 eth1)
        declare -a   to=(eth0 eth1 eth2 eth3 eth4 eth5 eth6 eth7 eth8 eth9)
        ;;
esac

# and for each element, map to a temporary interface named new_ethx
udev_file='/etc/udev/rules.d/70-persistent-net.rules';
for (( i = 0 ; i < ${#from[@]} ; i++ )); do
    perl -i -pe "s/NAME\=\"${from[$i]}\"/NAME\=\"new_${to[$i]}\"/g" $udev_file
done
# then remove all the "new_".  We do the intermeidate step to avoid renaming collisions
perl -i -pe "s/new_//g" $udev_file 

echo "Remapped ports for $model appliance, changes take effect after reboot..."
