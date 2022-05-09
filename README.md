# 群晖NAS部署clash透明代理
* 可安装于ARM架构的群晖
* 无需Docker或虚拟机
* 可以由群晖开启DHCP服务器，并将网关和DNS指向群晖，即可实现局域网设备的自动全局代理
* 因为群晖为定制版Linux，代理UDP流量需要补齐缺失的iptables模块
* 因为后续clash配置文件可能经常需要修改，建议将配置文件目录定义在`共享文件夹`目录下

安装过程需开启群晖的SSH功能，并通过`sudo -i`切换到root用户

请将群晖设置为静态IP

本文以armv8架构为例，且clash的配置目录为`/volume1/homes/clash`

## 安装clash

1. 下载最新版本，地址请前往[Dreamacro/clash](https://github.com/Dreamacro/clash/releases)，根据架构替换最新版本下载地址（以下以armv8架构为例）
```bash
wget https://github.com/Dreamacro/clash/releases/download/v1.10.0/clash-linux-armv8-v1.10.0.gz
```

2. 解压
```bash
gzip -d clash-linux-armv8-v1.10.0.gz
```

3. 安装到系统 PATH
```bash
chmod +x clash-linux-armv8-v1.10.0
mv clash-linux-armv8-v1.10.0 /usr/bin/clash
```

## 安装clash-通过脚本（测试）

运行一键安装脚本
仅在DS118/DS218机型（armv8）架构测试通过，
```bash
wget -qO- https://github.com/412999826/clash-synology/raw/main/install.sh | bash
```

## 创建配置文件及安装控制面板

1. 创建配置文件目录(如果上文配置目录的路径为`共享文件夹`目录，也可右键新建文件夹)
```bash
mkdir -p /volume1/homes/clash
```

2. 下载clash控制面板，提供2个版本

* [Dreamacro/clash-dashboard](https://github.com/Dreamacro/clash-dashboard/archive/refs/heads/gh-pages.zip)

* [haishanh/yacd](https://github.com/haishanh/yacd/archive/refs/heads/gh-pages.zip)

4. 解压，并将控制面板目录重命名为clash-ui，上传至clash配置目录下

5. 创建yaml配置文件并存放到clash配置目录

    以下放出针对本次透明代理的重点内容，完整配置请前往[Dreamacro/clash Wiki](https://github.com/Dreamacro/clash/wiki/configuration#all-configuration-options)获取。

```bash
# HTTP端口
port: 7890
# SOCKS5端口
socks-port: 7891
# 透明代理端口
redir-port: 7892
#允许来自局域网的连接
allow-lan: true
日志级别
log-level: info
# 控制面板端口
external-controller: 0.0.0.0:9090
# 控制面板路径
external-ui: clash-ui
# 控制面板密码
secret: "123456"
# dns设置
dns:
  enable: true
  ipv6: false
  listen: 0.0.0.0:1053
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver:
    - 114.114.114.114
    - https://dns.alidns.com/dns-query
  fallback:
    - tls://8.8.4.4:853
    - https://dns.pub/dns-query
```

## 设置clash自启动服务

1. Systemd 配置文件
* 启动vi编辑器
```bash
vi /etc/systemd/system/clash.service
```

* 按`I`进入编辑模式，键入以下内容（`-d` 后面键入clash配置文件目录）
```bash
[Unit]
Description=Clash daemon, A rule-based proxy in Go.
After=network.target

[Service]
Type=simple
Restart=always
ExecStart=/usr/bin/clash -d /volume1/homes/clash

[Install]
WantedBy=multi-user.target
```

* 按`ESC`，键入`:wq`退出

2. 立即运行并设置系统启动时运行
```bash
systemctl start udpxy
systemctl enable udpxy
```

## 配置防火墙转发规则(iptables)
1. 如果无需代理udp流量，请注释掉脚本中`配置udp透明代理`部分内容
2. 如果需要代理udp流量，请前往[syno-iptables](https://github.com/sjtuross/syno-iptables)下载/自行编译群晖缺失的iptables组件，并按上述仓库教程进行安装(无需运行加载命令，加载命令已经包含在脚本中)
3. 创建计划任务启动时自动配置防火墙
* 转到：DSM>控制面板>计划任务
* 新增>触发的任务>用户定义的脚本
  * 常规
    * 任务：活动软件
    * 用户：root
    * 事件：启动
    * 任务前：无
  * 任务设置
    * 运行命令：（请参阅下面的命令）

```bash
#!/bin/bash

# 加载内核
modprobe ip_tables

# 定义环境变量
proxy_port=7892                  #clash 代理端口
fake_ip_range='198.18.0.0/16'    #clash fake-ip范围
dns_port=1053                    #clash dns监听端口

# 启用ipv4 forward
sysctl -w net.ipv4.ip_forward=1

# 配置tcp透明代理
## 在nat表中新建clash规则链
iptables -t nat -N clash
## 排除环形地址与保留地址
iptables -t nat -A clash -d 0.0.0.0/8 -j RETURN
iptables -t nat -A clash -d 10.0.0.0/8 -j RETURN
iptables -t nat -A clash -d 127.0.0.0/8 -j RETURN
iptables -t nat -A clash -d 169.254.0.0/16 -j RETURN
iptables -t nat -A clash -d 172.16.0.0/12 -j RETURN
iptables -t nat -A clash -d 192.168.0.0/16 -j RETURN
iptables -t nat -A clash -d 224.0.0.0/4 -j RETURN
iptables -t nat -A clash -d 240.0.0.0/4 -j RETURN
## 重定向tcp流量到clash 代理端口
iptables -t nat -A clash -p tcp -j REDIRECT --to-port "$proxy_port"
## 拦截外部tcp数据并交给clash规则链处理
iptables -t nat -A PREROUTING -p tcp -j clash
## fake-ip tcp规则添加
iptables -t nat -A OUTPUT -p tcp -d "$fake_ip_range" -j REDIRECT --to-port "$proxy_port"

# 配置udp透明代理
## 加载模块
insmod /lib/modules/nf_defrag_ipv6.ko
insmod /lib/modules/xt_TPROXY.ko
## 设置防火墙参数
ip rule add fwmark 1 table 100
ip route add local default dev lo table 100
## 在mangle表中新建clash规则链
iptables -t mangle -N clash
## 排除环形地址与保留地址
iptables -t mangle -A clash -d 0.0.0.0/8 -j RETURN
iptables -t mangle -A clash -d 10.0.0.0/8 -j RETURN
iptables -t mangle -A clash -d 127.0.0.0/8 -j RETURN
iptables -t mangle -A clash -d 169.254.0.0/16 -j RETURN
iptables -t mangle -A clash -d 172.16.0.0/12 -j RETURN
iptables -t mangle -A clash -d 192.168.0.0/16 -j RETURN
iptables -t mangle -A clash -d 224.0.0.0/4 -j RETURN
iptables -t mangle -A clash -d 240.0.0.0/4 -j RETURN
## 重定向udp流量到clash 代理端口
iptables -t mangle -A clash -p udp -j TPROXY --on-port "$proxy_port" --tproxy-mark 1
## 拦截外部udp数据并交给clash规则链处理
iptables -t mangle -A PREROUTING -p udp -j clash
## fake-ip udp规则添加
iptables -t mangle -A OUTPUT -p udp -d "$fake_ip_range" -j MARK --set-mark 1

# DNS 相关配置
## 拦截外部upd的53端口流量交给clash_dns规则链处理
iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port "$dns_port"

# 修复 ICMP(ping)
# 这并不能保证 ping 结果有效(clash 不支持转发 ICMP), 只是让它有返回结果而已
# --to-destination 设置为一个可达的地址即可
iptables -t nat -A PREROUTING -p icmp -d 198.18.0.0/16 -j DNAT --to-destination 192.168.1.1
```
