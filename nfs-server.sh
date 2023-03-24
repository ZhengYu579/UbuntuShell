#!/bin/bash

# 显示帮助信息
function show_help {
    echo "Usage: \$0 [-h] [-d <directory>] [-i <clientip>]"
    echo "  -h             显示帮助信息"
    echo "  -d <directory> 指定要挂载的目录（默认为/nfs）"
    echo "  -i <clientip>  指定允许连接的客户端ip（默认为 *）"
}

# 设置默认值
directory=/nfs
clientip="*"

# 解析命令行选项
while getopts ":hd:i:" opt; do
    case ${opt} in
        h )
            show_help
            exit 0
            ;;
        d )
            directory=$OPTARG
            ;;
        i )
            clientip=$OPTARG
            ;;
        : )
            echo "Error: -$OPTARG requires an argument."
            exit 1
            ;;
        \? )
            echo "Error: Invalid option -$OPTARG"
            exit 1
            ;;
    esac
done

# 检查目录是否存在，如果不存在则创建目录并添加权限
if [ ! -d "$directory" ]; then
    sudo mkdir -p $directory
    sudo chmod +rw -R $directory
fi

# 添加测试文件
    sudo touch $directory/test.txt
    sudo chmod 666 $directory/test.txt
    sudo echo "这是一个用于测试nfs 服务器是否可以正常挂载的测试文本" > $directory/test.txt

# 检查NFS服务器是否已安装
if [ ! $(dpkg-query -W -f='\${Status}' nfs-kernel-server 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
    # 如果没有安装，则安装NFS服务器
    sudo apt-get update
    sudo apt-get install nfs-kernel-server -y
fi
echo
echo "NFS server is already installed."

# 配置NFS共享目录
sudo sh -c "echo '$directory $clientip(rw,sync,no_subtree_check)' > /etc/exports"

# 重启NFS服务器
sudo systemctl restart nfs-kernel-server

echo "NFS server is now running with shared directory $directory and IP address $clientip"
echo
echo "*******************************************"
echo "* 生成用于连接NFS服务器的脚本connect_nfs.sh *"
echo "*     使用./connect_nfs.sh -h查看帮助      *"
echo "*******************************************"

# 获取当前正在使用的网络接口
interface=$(ip route get 8.8.8.8 | awk 'NR==1 {print $5}')

# 获取网络接口的IPv4地址
local_ip=$(ip addr show $interface | grep inet | grep -v inet6 | awk '{ print $2 }' | awk -F'/' '{ print $1 }')

echo "#!/bin/bash" > connect_nfs.sh

echo "
# 显示帮助信息
function show_help {
    echo \"Usage: \$0 [-h] [-d <directory>]\"
    echo \"  -h             显示帮助信息\"
    echo \"  -d <directory> 指定要挂载的目录（默认为/mnt/nfs）\"
}" >> connect_nfs.sh

echo "
# 设置默认值
directory=/mnt/nfs" >> connect_nfs.sh

echo "
# 解析命令行选项
while getopts ":hd:" opt; do
    case \${opt} in
        h )
            show_help
            exit 0
            ;;
        d )
            directory=\$OPTARG
            ;;
        : )
            echo "Error: -\$OPTARG requires an argument."
            exit 1
            ;;
        \? )
            echo "Error: Invalid option -\$OPTARG"
            exit 1
            ;;
    esac
done" >> connect_nfs.sh

echo "
# 检查目录是否存在，如果不存在则创建目录并添加权限
if [ ! -d "\$directory" ]; then
    sudo mkdir -p \$directory
    sudo chmod +rw -R \$directory
fi" >> connect_nfs.sh

echo "mount -t nfs $local_ip:$directory \$directory" >> connect_nfs.sh
chmod +x connect_nfs.sh
