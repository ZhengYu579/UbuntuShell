#!/bin/bash

# Default values
tftp_root="/tftpboot"

# Help function
function show_help {
  cat << EOF
Usage: $(basename "\$0") [-h] [-r TFTP_ROOT]

Install and configure TFTP server.

Available options:

-h, --help      Show this help message and exit.
-r, --root      TFTP root directory (default: /tftpboot).
EOF
}

# Parse command line options
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -h|--help)
      show_help
      exit 0
      ;;
    -r|--root)
      tftp_root=$2
      shift
      shift
      ;;
    *)
      echo "Invalid option: $key"
      show_help
      exit 1
      ;;
  esac
done

# Get absolute path of script directory
script_dir=$(dirname "$(readlink -f "\$0")")

# Convert tftp_root to absolute path
tftp_root=$(realpath "$tftp_root")

# Combine script directory and tftp_root to form absolute path
absolute_path="$script_dir/$tftp_root"

# Check if TFTP root directory exists
if [ ! -d "$tftp_root" ]; then
  sudo mkdir -p "$tftp_root"
  sudo chown -R nobody:nogroup "$tftp_root"
  sudo chmod -R 777 "$tftp_root"
fi

sudo sh -c "echo '这是一个为了测试tftp服务器生成的测试文本'>$tftp_root/test.txt"

# Install required packages
sudo apt-get update
sudo apt-get install -y tftp-hpa tftpd-hpa xinetd

# Configure /etc/default/tftpd-hpa
sudo tee /etc/default/tftpd-hpa >/dev/null <<EOF
# /etc/default/tftpd-hpa

TFTP_USERNAME="tftp"
TFTP_DIRECTORY="$tftp_root"
TFTP_ADDRESS="0.0.0.0:69"
TFTP_OPTIONS="-l -c -s"
EOF

# Configure /etc/xinetd.conf
sudo tee /etc/xinetd.conf >/dev/null <<EOF
# Simple configuration file for xinetd
#
# Some defaults, and include /etc/xinetd.d/
defaults
{
    # Please note that you need a log_type line to be able to use log_on_success
    # and log_on_failure. The default is the following :
    # log_type = SYSLOG daemon info
}
includedir /etc/xinetd.d
EOF

# Configure /etc/xinetd.d/tftp
sudo tee /etc/xinetd.d/tftp >/dev/null <<EOF
service tftp
{
    socket_type = dgram
    wait = yes 
    disable = no
    user = root
    protocol = udp 
    server = /usr/sbin/in.tftpd
    server_args = -s $tftp_root
    #log_on_success += PID HOST DURATION
    #log_on_failure += HOST
    per_source = 11
    cps =100 2
    flags =IPv4
}
EOF

sudo service tftpd-hpa restart
sudo /etc/init.d/xinetd reload
sudo /etc/init.d/xinetd restart

TFTP_SERVER_IP=$(hostname -I | awk '{print $1}')

echo "TFTP server is running at $TFTP_SERVER_IP"
echo 
echo "***********************************************************************************************"
echo "To connect to the TFTP server and perform file transfer operations, use the following commands:"
echo "tftp $TFTP_SERVER_IP"
echo "tftp> get <file_name>"
echo "tftp> put <file_name>"
echo "tftp> quit"
echo "***********************************************************************************************"
