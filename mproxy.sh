#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
clear
echo -e "\033[34m================================================================\033[0m

                欢迎使用 Mproxy 一键脚本

            系统要求:  CentOS 6,7, Debian, Ubuntu
            描述: 一键安装 Mproxy 服务器
            作者: DengXizhen
            联系方式： 1613049323@qq.com

\033[34m================================================================\033[0m";

echo
echo "脚本支持CentOS 6,7, Debian, Ubuntu系统(如遇到卡住，请耐心等待5-7分钟)"
echo

# Make sure only root can run our script
function rootness(){
    if [[ $EUID -ne 0 ]]; then
        echo -e "\033[31m 错误：本脚本必须以root用户执行！\033[0m" 1>&2
        exit 1
    fi
}

# Check OS
function checkos(){
    if [ -f /etc/redhat-release ];then
        OS='CentOS'
    elif [ ! -z "`cat /etc/issue | grep bian`" ];then
        OS='Debian'
    elif [ ! -z "`cat /etc/issue | grep Ubuntu`" ];then
        OS='Ubuntu'
    else
        echo -e "\033[31m 不支持该操作系统，请重新安装并重试！\033[0m"
        exit 1
    fi
}

# Get version
function getversion(){
    if [[ -s /etc/redhat-release ]];then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else    
        grep -oE  "[0-9.]+" /etc/issue
    fi    
}

# CentOS version
function centosversion(){
    local code=$1
    local version="`getversion`"
    local main_ver=${version%%.*}
    if [ $main_ver == $code ];then
        return 0
    else
        return 1
    fi
}

# Set firewall
function firewall_set(){
    echo "正在设置防火墙..."
    if centosversion 6; then
        /etc/init.d/iptables status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            iptables -L -n | grep '${mproxyport}' | grep 'ACCEPT' > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${mproxyport} -j ACCEPT
                iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${mproxyport} -j ACCEPT
                /etc/init.d/iptables save
                /etc/init.d/iptables restart
            else
                echo "端口 ${mproxyport} 已设置。"
            fi
        else
            echo -e "\033[31m 警告：iptables 看起来好像已关闭或未安装，如果必要的话请手动设置它。\033[0m"
        fi
    elif centosversion 7; then
        systemctl status firewalld > /dev/null 2>&1
        if [ $? -eq 0 ];then
            firewall-cmd --permanent --zone=public --add-port=${mproxyport}/tcp
            firewall-cmd --permanent --zone=public --add-port=${mproxyport}/udp
            firewall-cmd --reload
        else
            echo "Firewalld 看起来好像未运行，正在启动..."
            systemctl start firewalld
            if [ $? -eq 0 ];then
                firewall-cmd --permanent --zone=public --add-port=${mproxyport}/tcp
                firewall-cmd --permanent --zone=public --add-port=${mproxyport}/udp
                firewall-cmd --reload
            else
                echo -e "\033[31m 警告：启动 firewalld 失败。如果必要的话请手动确保端口${mproxyport}能使用。\033[0m"
            fi
        fi
    fi
    echo "firewall 设置完毕..."
}

# 不支持 CentOS 5
if centosversion 5; then
    echo -e "\033[31m 不支持 CentOS 5, 请更新操作系统至 CentOS 6+/Debian 7+/Ubuntu 12+ 并重试。\033[0m"
    exit 1
fi

# Install Mproxy
function install_mproxy(){
    # Make sure only root can run our script
    rootness

    # Install necessary dependencies
    checkos
    if [ "$OS" == 'CentOS' ]; then
        yum install -y wget gcc gcc-c++ readline-devel pcre-devel openssl-devel tcl perl
    else
        apt-get -y update
        apt-get -y install gcc gcc-c++ readline-devel pcre-devel openssl-devel tcl perl
    fi

    # Download file
    if ! wget --no-check-certificate -O /var/local/mproxy.zip https://codeload.github.com/crazy886/mproxy/zip/master; then
        echo -e "\033[31m 下载 mproxy.zip 文件失败！\033[0m"
        exit 1
    else
        cd /var/local
        killall /var/local/mproxy-master/mproxy > /dev/null 2>&1
        rm -rf /var/local/mproxy-master > /dev/null 2>&1
        unzip /var/local/mproxy.zip
        rm -f /var/local/mproxy.zip
    fi

    # Compile
    # gcc -o /var/local/mproxy /var/local/mproxy-master/mproxy.c

    # Start Mproxy
    mproxyport=80
    echo -n $mproxyport > /var/local/mproxy-master/port
    chmod +x /var/local/mproxy-master/mproxy
    /var/local/mproxy-master/mproxy -l $mproxyport -d

    # Start firewall
    if [ "$OS" == 'CentOS' ]; then
       firewall_set > /dev/null 2>&1
    fi
    
    # Get public IP address
    IP=$(ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1)
    if [[ "$IP" = "" ]]; then
        IP=$(wget -qO- -t1 -T2 ipv4.icanhazip.com)
    fi
    echo -e "IP: \033[41;37m ${IP} \033[0m"
    echo -e "PORT: \033[41;37m ${mproxyport} \033[0m"
    echo -e "CONNECT连接目标: \033[41;37m dream~ [host] \033[0m"
}

# Check the status of Mproxy
function status_mproxy(){
    [ ! -e /var/local/mproxy-master/mproxy ] && echo -e "\033[31m 尚未安装 Mproxy！\033[0m" && exit 1
    pid=`ps -ef | grep /var/local/mproxy-master/mproxy | grep -v grep | sed 's/[ ][ ]*/ /g' | cut -d " " -f 2`
    [ -z $pid ] && echo "Mproxy is stoped." || echo "Mproxy is running, and pid is $pid." 
}

# Restart Mproxy
function restart_mproxy(){
    [ ! -e /var/local/mproxy-master/mproxy ] && echo -e "\033[31m 尚未安装 Mproxy！\033[0m" && exit 1
    echo "正在重启 Mproxy ..."
    killall /var/local/mproxy-master/mproxy > /dev/null 2>&1
    mproxyport=`cat /var/local/mproxy-master/port`
    /var/local/mproxy-master/mproxy -l $mproxyport -d
    status_mproxy
}

# Initialization step
action=$1
[ -z $1 ] && action=install
case "$action" in
install)
    install_mproxy
    ;;
uninstall)
    uninstall_mproxy
    ;;
restart)
    restart_mproxy
    ;;
status)
    status_mproxy
    ;;
*)
    echo "参数错误! [${action} ]"
    echo "Usage: `basename $0` {install|uninstall|restart|status}"
    ;;
esac
