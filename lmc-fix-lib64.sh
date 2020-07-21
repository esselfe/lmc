#!/bin/bash

# Recreate the install cache archives having the /usr/lib64 link
# in file paths... tar doesn't extract those and fail.

mkdir /tmp/lmc 2>/dev/null
cd /tmp/lmc

[ ! -e lmc-list.txt ] &&
	wget --no-cache -T16 https://hobby.esselfe.ca/lmc-list.txt -O lmc-list.txt

cat lmc-list.txt | while read LINE; do
	MODULE=$(echo "$LINE" | awk '{ print $1 }')
	VERSION=$(echo "$LINE" | awk '{ print $2 }')
	FILENAME="$MODULE-$VERSION-x86_64-pc-linux-gnu.tar"
	LIST=$(xzcat "/var/cache/lunar/$FILENAME.xz" |
		tar --list 2>&1 | sed '/Removing leading /d')
	echo "$LIST" | grep "^/usr/lib64" >/dev/null && {
		LIST=$(echo "$LIST" | sed 's@^/usr/lib64@/usr/lib@g')
		CNT=0
		echo "creating $FILENAME.xz"
		echo "$LIST" | while read FILE; do
			if [ $((++CNT)) -eq 1 ]; then
				tar --no-recursion -cPf $FILENAME "$FILE"
			else
				tar --no-recursion -Pf $FILENAME --append "$FILE"
			fi
		done
		xz "$FILENAME"
	}
done

