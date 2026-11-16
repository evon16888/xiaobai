#!/bin/bash

# ==========================================
# 全局防交互环境变量配置
# ==========================================
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# 核心：提前静默预设键盘和时区，彻底杜绝 debconf 弹窗
echo "keyboard-configuration keyboard-configuration/layout select English (US)" | sudo debconf-set-selections
echo "keyboard-configuration keyboard-configuration/layoutcode select us" | sudo debconf-set-selections
echo "tzdata tzdata/Areas select Asia" | sudo debconf-set-selections
echo "tzdata tzdata/Zones/Asia select Shanghai" | sudo debconf-set-selections

# 之后的安装命令就可以畅通无阻了...

# 1. 安装 Anaconda
echo "开始安装 miniconda3..."
mkdir -p ~/miniconda3
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
rm ~/miniconda3/miniconda.sh

# 激活base环境
source ~/miniconda3/bin/activate

# 替代 conda init --all，直接写入环境变量，避免交互询问
echo 'export PATH="$HOME/miniconda3/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 配置 channel（自动接受服务条款）
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main -y 2>/dev/null || true
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r -y 2>/dev/null || true
conda --version

# 2. 安装 PM2 依赖及 Node.js
echo "开始安装 PM2..."
sudo apt --fix-broken install -y
sudo apt-get update && sudo apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# 终极静默安装 nodejs npm
sudo apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" nodejs npm

# 安装 PM2
sudo npm install -g pm2
pm2 install pm2-logrotate
pm2 --version

# 3. 创建 Python 3.8.18 的 Alpha 环境
echo "创建 Python 3.8.18 的 Alpha 环境..."
conda create -n Alpha python==3.8.18 -y
conda activate Alpha

# 安装 ta-lib
conda install -c conda-forge ta-lib==0.4.19 -y
python --version

# 4. 安装 requirements.txt
echo "安装 requirements.txt ..."
pip install -r https://raw.githubusercontent.com/evon16888/xiaobai/refs/heads/main/requirements.txt

# 5. 安装 Htop
echo "安装 Htop..."
sudo apt-get install -y htop

# 6. MySQL 安装与 GitHub 初始化
echo "[+] 开始安装与配置 MySQL..."
DB_NAME="alpha"
DB_USER="work"
DB_PASS="Www.top123@"   # 请修改为您的 MySQL 密码
INIT_SQL_URL="https://raw.githubusercontent.com/evon16888/xiaobai/refs/heads/main/init.sql" # 确保这里是你的 init.sql 真实 Raw 链接
INIT_SQL_PATH="./init.sql"

sudo apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" mysql-server mysql-client curl wget

sudo systemctl start mysql
sudo systemctl enable mysql

if ! sudo systemctl is-active --quiet mysql; then
  echo "[-] MySQL 服务启动失败，请检查日志！"
  exit 1
fi

echo "[+] 正在从 GitHub 下载初始化文件..."
if command -v curl &> /dev/null; then
    curl -s -L -o "${INIT_SQL_PATH}" "${INIT_SQL_URL}"
elif command -v wget &> /dev/null; then
    wget -q -O "${INIT_SQL_PATH}" "${INIT_SQL_URL}"
else
    echo "[-] 错误: 未找到 curl 或 wget 工具，无法下载文件！"
    exit 1
fi

if [ ! -f "${INIT_SQL_PATH}" ] || [ ! -s "${INIT_SQL_PATH}" ]; then
  echo "[-] 错误: 初始化文件下载失败，请检查 URL 是否正确或网络是否畅通。"
  exit 1
fi

echo "[+] 正在执行数据库与用户初始化..."
sudo mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF

echo "[+] 正在导入初始化文件到数据库 ${DB_NAME}..."
sudo mysql -u root "${DB_NAME}" < "${INIT_SQL_PATH}"
echo "[+] MySQL 初始化 SQL 导入成功！"
rm -f "${INIT_SQL_PATH}"

# 7. 设置虚拟内存 (Swap)
if [ -f "/swap.img" ]; then
    sudo swapoff /swap.img
    sudo rm /swap.img
fi
if ! grep -q "/swapfile" /etc/fstab; then
    sudo fallocate -l 8G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

# 8. 解决中文乱码（字体安装）
echo "开始安装字体..."
sudo mkdir -p /usr/share/fonts/
cd /usr/share/fonts/
sudo wget -q https://github.com/adobe-fonts/source-han-sans/releases/download/2.004R/SourceHanSansSC.zip -O SourceHanSansSC.zip
sudo apt-get install -y unzip
# 加上 -o 参数覆盖时不弹出询问
sudo unzip -o SourceHanSansSC.zip
sudo mv OTF/ SourceHanSans/ 2>/dev/null || true
sudo fc-cache -fv
rm -rf ~/.cache/matplotlib
rm -f SourceHanSansSC.zip

# 完成
echo "miniconda3、PM2、SourceHanSansSC字体、8G虚拟内存、Htop、MySQL及自动初始化、Python 环境全部安装完成！"

# 启动新的交互式 shell
exec $SHELL
