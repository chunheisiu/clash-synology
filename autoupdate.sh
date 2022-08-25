#!/bin/bash

get_latest_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                            # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}

set -e "$1"

latest_release_tag=$(get_latest_release Dreamacro/clash)
ver=$(/usr/bin/clash -v)
arch=$(uname -m)
[ "$arch" == 'x86_64' ] && board_id='amd64'
[ "$arch" == 'aarch64' ] && board_id='armv8'
[ "$arch" == 'armv7' ] && board_id='armv7'
[ "$arch" == 'armv5' ] && board_id='armv5'

microarch=''

if [[ $arch == 'x86_64' ]]; then
  # https://unix.stackexchange.com/a/631320
  flags=$(grep '^flags\b' </proc/cpuinfo | head -n 1)
  flags=" ${flags#*:} "

  has_flags() {
    for flag; do
      case "$flags" in
      *" $flag "*) : ;;
      *)
        if [ -n "$verbose" ]; then
          echo >&2 "Missing $flag for the next level"
        fi
        return 1
        ;;
      esac
    done
  }

  determine_level() {
    level=0
    has_flags lm cmov cx8 fpu fxsr mmx syscall sse2 || return 0
    level=1
    has_flags cx16 lahf_lm popcnt sse4_1 sse4_2 ssse3 || return 0
    level=2
    has_flags avx avx2 bmi1 bmi2 f16c fma abm movbe xsave || return 0
    level=3
    has_flags avx512f avx512bw avx512cd avx512dq avx512vl || return 0
    level=4
  }

  determine_level
  [[ $level -ge 3 ]] && microarch='-v3'
fi

if [[ $ver =~ $latest_release_tag ]]; then
  echo "已是最新版本，升级中止！" && exit 1
else
  echo "准备更新到 $latest_release_tag"
fi

wget -q "https://github.com/Dreamacro/clash/releases/download/$latest_release_tag/clash-linux-$board_id$microarch-$latest_release_tag.gz"
gzip -d "clash-linux-$board_id$microarch-$latest_release_tag.gz"
chmod +x "clash-linux-$board_id$microarch-$latest_release_tag"
systemctl stop clash
mv "clash-linux-$board_id$microarch-$latest_release_tag" /usr/bin/clash
systemctl start clash
