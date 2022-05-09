#!/bin/sh

get_latest_release() {
	curl --silent "https://api.github.com/repos/$1/releases/latest" |	# Get latest release from GitHub api
	grep '"tag_name":' |												# Get tag line
	sed -E 's/.*"([^"]+)".*/\1/'										# Pluck JSON value
}

set -e $1

latest_release_tag=`get_latest_release Dreamacro/clash`
ver=`/usr/bin/clash -v`
arch=`uname -m`
[ $arch == 'x86_64' ] && board_id='amd64';
[ $arch == 'aarch64' ] && board_id='armv8';
[ $arch == 'armv7' ] && board_id='armv7';
[ $arch == 'armv5' ] && board_id='armv5';

if [[ $ver =~ $latest_release_tag ]]; then
	echo 已是最新版本，升级中止！ && exit 1
else
	echo 准备更新到$latest_release_tag
fi
wget https://github.com/Dreamacro/clash/releases/download/$latest_release_tag/clash-linux-$board_id-$latest_release_tag.gz
gzip -d clash-linux-$board_id-$latest_release_tag.gz
chmod +x clash-linux-$board_id-$latest_release_tag
systemctl stop clash
mv clash-linux-$board_id-$latest_release_tag /usr/bin/clash
systemctl start clash
