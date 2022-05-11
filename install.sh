#!/bin/bash

get_latest_release() {
	curl --silent "https://api.github.com/repos/$1/releases/latest" |	# Get latest release from GitHub api
	grep '"tag_name":' |												# Get tag line
	sed -E 's/.*"([^"]+)".*/\1/'										# Pluck JSON value
}

set -e $1

latest_release_tag=`get_latest_release Dreamacro/clash`
arch=`uname -m`

[ $arch == 'x86_64' ] && board_id='amd64';
[ $arch == 'aarch64' ] && board_id='armv8';
[ $arch == 'armv7' ] && board_id='armv7';
[ $arch == 'armv5' ] && board_id='armv5';

wget https://github.com/Dreamacro/clash/releases/download/$latest_release_tag/clash-linux-$board_id-$latest_release_tag.gz
gzip -d clash-linux-$board_id-$latest_release_tag.gz
chmod +x clash-linux-$board_id-$latest_release_tag
mv clash-linux-$board_id-$latest_release_tag /usr/bin/clash
