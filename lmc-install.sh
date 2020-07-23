#!/bin/bash

# Note that this script is still in alpha stage
# and has not been fully tested yet

LMC_VERSION="0.1.4"
[ "$1" = "-V" ] && {
	echo "$LMC_VERSION"
	exit 0
}

[ -d /etc/lunar ] || {
	echo "error: this script must be run on a Lunar-Linux system"
	exit 1
}

SITE=https://hobby.esselfe.ca

# lmc-list.txt is made of lines describing the module name, the version,
# the install cache archive size and installed total size, like
# xterm 358 353724 952320
wget $SITE/lmc-list.txt -O /tmp/lmc-list.txt

# fetch the archives
cd /var/cache/lunar
CNT=0
CNT_TOTAL=$(wc -l /tmp/lmc-list.txt | awk '{ print $1 }')
TOTAL_SIZE=0
STR="0"
for i in $(awk '{ print $3 }' /tmp/lmc-list.txt); do
	STR="$STR+$i"
done
TOTAL_SIZE=$(echo "scale=1; ($STR)/1000000" | bc)
SIZE_DONE=0
echo "Fetching $CNT_TOTAL archives totalling ${TOTAL_SIZE}MB"
time cat /tmp/lmc-list.txt | while read LINE; do
#time head -n5 /tmp/lmc-list.txt | while read LINE; do
	MODULE=$(echo "$LINE" | awk '{ print $1 }')
	VERSION=$(echo "$LINE" | awk '{ print $2 }')
	if [ "$MODULE" -eq "rustc" ]; then
		FILE="$MODULE-$VERSION-unknown-linux-gnu.tar.xz"
	else
		FILE="$MODULE-$VERSION-x86_64-pc-linux-gnu.tar.xz"
	fi
	SIZE=$(echo "$LINE" | awk '{ print $3 }')
	SIZE_DONE=$((SIZE_DONE+SIZE))
	SIZE_DONE_H=$(echo "scale=2; $SIZE_DONE/1000000" | bc)
	echo -n "$((++CNT))/$CNT_TOTAL $SIZE_DONE_H/${TOTAL_SIZE}MB $FILE"
	if [ -e "$FILE" ]; then
		# Since some downloads fails mysteriously with incompletle size 
		# in a qemu vm, retry to continue from where it left
		CUR_SIZE=$(stat --printf="%s" "$FILE")
		if [[ $CUR_SIZE -eq $SIZE ]]; then
			echo " (cached)"
		elif [[ $CUR_SIZE -lt $SIZE ]]; then
			echo " (continuing)"
			wget -c -q --show-progress --no-cache $SITE/lmc/$FILE || {
				grep "$FILE" /tmp/lmc-failed-download.txt &>/dev/null ||
					echo "$FILE" >> /tmp/lmc-failed-download.txt
			}
		fi
	else
		echo ""
		wget -q --show-progress --no-cache $SITE/lmc/$FILE ||
			echo "$FILE" >> /tmp/lmc-failed-download.txt
	fi
done

# extract the archives
cd /
CNT=0
TOTAL_SIZE=0
time cat /tmp/lmc-list.txt | while read LINE; do
#time head -n5 /tmp/lmc-list.txt | while read LINE; do
	MODULE=$(echo "$LINE" | awk '{ print $1 }')
	VERSION=$(echo "$LINE" | awk '{ print $2 }')
	if [ "$MODULE" -eq "rustc" ]; then
		FILE="$MODULE-$VERSION-unknown-linux-gnu.tar.xz"
	else
		FILE="$MODULE-$VERSION-x86_64-pc-linux-gnu.tar.xz"
	fi
	grep "$(basename $FILE)" /tmp/lmc-failed-download.txt &>/dev/null && continue;
	SIZE=$(echo "$LINE" | awk '{ print $3 }')
	SIZE_H="$(echo $SIZE/1000 | bc)KB"
	INSTALLED_SIZE=$(echo "$LINE" | awk '{ print $4 }')
	echo "Extracting $((++CNT))/$CNT_TOTAL $FILE"
	STR=$(tar xf /var/cache/lunar/$FILE 2>&1)
	if [ $? -ne 0 ]; then
		# might be tar refusing to work with /usr/lib64 as a link
		echo "Retrying from another directory"
		[ ! -d /tmp/lmc ] && mkdir /tmp/lmc
		cd /tmp/lmc
		STR="$(tar xf /var/cache/lunar/$FILE 2>&1)"
		RET=$?
		echo "$STR" | sed '/Removing leading /d'
		if [ $RET -ne 0 ]; then
			echo "$FILE" >> /tmp/lmc-failed-extract.txt
		else
			cp -rd * /
			TOTAL_SIZE=$((TOTAL_SIZE+SIZE))
			echo "$TOTAL_SIZE" >/tmp/lmc-totalsize
			# mark the module as installed for the Lunar module manager
			grep "^$MODULE:" /var/state/lunar/packages &>/dev/null ||
				echo "$MODULE:$(date +%Y%m%d):installed:$VERSION:$SIZE_H" >>/var/state/lunar/packages
		fi
		rm -rf *
		cd /
	else
		# remove annoying tar messages
		echo "$STR" | sed '/Removing leading /d'
		TOTAL_SIZE=$((TOTAL_SIZE+SIZE))
		echo "$TOTAL_SIZE" >/tmp/lmc-totalsize
		# mark the module as installed for the Lunar module manager
		grep "^$MODULE:" /var/state/lunar/packages &>/dev/null ||
			echo "$MODULE:$(date +%Y%m%d):installed:$VERSION:$SIZE_H" >> /var/state/lunar/packages
	fi
done
TOTAL_SIZE_H=$(echo "scale=1; $(cat /tmp/lmc-totalsize)/1000000" | bc)
echo "Total installed size: ${TOTAL_SIZE_H}MB"

# summary
[ -e /tmp/lmc-failed-download.txt ] && {
	echo -e "\nFailed downloads:"
	cat /tmp/lmc-failed-download.txt
	rm /tmp/lmc-failed-download.txt
}
[ -e /tmp/lmc-failed-extract.txt ] && {
	echo -e "\nFailed extractions:"
	cat /tmp/lmc-failed-extract.txt
	rm /tmp/lmc-failed-extract.txt
}

# clean up
[ -d /tmp/lmc ] && rm -rf /tmp/lmc
rm /tmp/lmc-{list,mods}.txt 2>/dev/null

