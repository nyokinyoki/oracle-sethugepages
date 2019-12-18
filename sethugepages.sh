#!/bin/bash

# Fancy bracketed notifications
OK="\e[1m[  \e[92mOK  \e[39m]\e[0m\t"
WARN="\e[1m[ \e[93mWARN \e[39m]\e[0m\t"
FAIL="\e[1m[ \e[91mFAIL \e[39m]\e[0m\t"
INFO="\e[1m[ \e[96mINFO \e[39m]\e[0m\t"

# Calculates memlock value to 95% of total memory on system
MEMLOCKVAL=$(($(free | grep Mem: | awk '{print $2}')*95/100))

if $(grep "^[^#;]" /etc/security/limits.conf | grep memlock)
then
	echo -e "$WARN Memlock already set in /etc/security/limits.conf, skipping addition"
	grep "^[^#;]" /etc/security/limits.conf | grep memlock
else
	echo -e "*\tsoft\tmemlock\t$MEMLOCKVAL" >> /etc/security/limits.conf
	echo -e "*\thard\tmemlock\t$MEMLOCKVAL" >> /etc/security/limits.conf
	echo -e "$OK Memlock values added to /etc/security/limits.conf"
fi


if [ "$(su oracle -c "ulimit -l")" eq "$MEMLOCKVAL" ]
then
	echo -e "$OK Memlock value matches ulimit -l command output"
else
	echo -e "$FAIL Memlock value does not match ulimit -l output"
	exit 1
fi
exit

### Oracle hugepages_settings.sh snippet
# Check for the kernel version
KERN=`uname -r | awk -F. '{ printf("%d.%d\n",$1,$2); }'`
# Find out the HugePage size
HPG_SZ=`grep Hugepagesize /proc/meminfo | awk '{print $2}'`
if [ -z "$HPG_SZ" ];
then
	echo -e "$FAIL The hugepages may not be supported in the system where the script is being executed."
	exit 1
fi
# Initialize the counter
NUM_PG=0
# Cumulative number of pages required to handle the running shared memory segments
for SEG_BYTES in `ipcs -m | cut -c44-300 | awk '{print $1}' | grep "[0-9][0-9]*"`
do
	MIN_PG=`echo "$SEG_BYTES/($HPG_SZ*1024)" | bc -q`
	if [ $MIN_PG -gt 0 ]
	then
		NUM_PG=`echo "$NUM_PG+$MIN_PG+1" | bc -q`
	fi
done
RES_BYTES=`echo "$NUM_PG * $HPG_SZ * 1024" | bc -q`
# An SGA less than 100MB does not make sense
# Bail out if that is the case
if [ $RES_BYTES -lt 100000000 ]
then
	echo "***********"
	echo "** ERROR **"
	echo "***********"
	echo "Sorry! There are not enough total of shared memory segments allocated for
	HugePages configuration. HugePages can only be used for shared memory segments
	that you can list by command:
	# ipcs -m
	of a size that can match an Oracle Database SGA. Please make sure that:
	* Oracle Database instance is up and running
	* Oracle Database 11g Automatic Memory Management (AMM) is not configured"
	exit 1
fi
# Finish with results
case $KERN in
'2.4') HUGETLB_POOL=`echo "$NUM_PG*$HPG_SZ/1024" | bc -q`;
echo "Recommended setting: vm.hugetlb_pool = $HUGETLB_POOL exiting" && exit 0 ;;
'2.6') echo "Recommended setting: vm.nr_hugepages = $NUM_PG" ;;
'3.8') echo "Recommended setting: vm.nr_hugepages = $NUM_PG" ;;
'3.10') echo "Recommended setting: vm.nr_hugepages = $NUM_PG" ;;
'4.1') echo "Recommended setting: vm.nr_hugepages = $NUM_PG" ;;
'4.14') echo "Recommended setting: vm.nr_hugepages = $NUM_PG" ;;
*) echo "Kernel version $KERN is not supported by this script (yet). Exiting." && exit 1;;
esac
### End of Oracle hugepages_settings.sh snippet


sysctl -w vm.nr_hugepages=$NUM_PG

if grep "vm.nr_hugepages" /etc/sysctl.conf
then
	echo "$WARN vm.mr_hugepages already present in /etc/sysctl.conf"
else
	echo -e "\n# HugePages setting according to https://docs.oracle.com/database/121/UNXAR/appi_vlm.htm#UNXAR403" >> /etc/sysctl.conf
	echo "vm.nr_hugepages = $NUM_PG" >> /etc/sysctl.conf
	echo -e "$OK adding vm.nr_hugepages = $NUM_PG to /etc/sysctl.conf"
fi

echo -e "$INFO Done. Check 'grep Huge /proc/meminfo' before and after reboot if the changes were successful."
exit 0
