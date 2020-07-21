#!/bin/bash

[ ! -d /tmp/lmc ] && mkdir /tmp/lmc 2>/dev/null
cd /tmp/lmc

[ -e lmc-list-tmp.txt ] && echo -n "" >lmc-list-tmp.txt
for m in $(awk -F: '{ print $1 }' /var/state/lunar/packages); do
	[ "$m" = "moonbase" -o "$m" = "dejavu-ttf" ] && continue;
	[ "$m" = "gnome-icon-theme"* -o "$m" = "maven" ] && continue;
	[ "$m" = "timidity-eawpatches" -o "$m" = "libreoffice-bin" ] && continue;
	[ "$m" = "man-pages" -o "$m" = "sun-jdk8" ] && continue;
	[ "$m" = "rustc" ] && continue;
	grep "^$m:" /var/state/lunar/module.index |
		grep ":core/" >/dev/null && continue;
	VERSION="$(lvu installed $m)"
	FILE=/var/cache/lunar/$m-$VERSION-x86_64-pc-linux-gnu.tar.xz
	SIZE=$(stat --printf="%s" $FILE)
	[ $? -ne 0 ] && continue;
	INSTALLED_SIZE=$(xzcat $FILE | wc -c)
	echo "$m $VERSION $SIZE $INSTALLED_SIZE" >>lmc-list-tmp.txt
done
sort lmc-list-tmp.txt > lmc-list.txt
rm lmc-list-tmp.txt

