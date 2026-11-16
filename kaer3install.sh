#!/bin/bash

# 安装 Anaconda
echo "开始安装 miniconda3..."
# 创建miniconda3存储的文件夹
mkdir -p ~/miniconda3
# 下载 Anaconda 安装脚本
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
# 运行安装脚本
bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
# 删除安装脚本
rm ~/miniconda3/miniconda.sh
# 激活base环境
source ~/miniconda3/bin/activate
# 初始化
conda init --all
# 配置channel
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
# 验证 Anaconda 安装
conda --version

# 安装 PM2
echo "开始安装 PM2..."
export DEBIAN_FRONTEND=noninteractive

# 终极静默安装命令（加了 dpkg 强制默认参数）
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    nodejs npm

# 更新环境
sudo apt --fix-broken install
sudo apt update && sudo apt upgrade -y
# 安装 Node.js（PM2 依赖 Node.js）
sudo apt install -y nodejs npm
# 安装 PM2
sudo npm install -g pm2
# 安装 PM2 日志管理工具
pm2 install pm2-logrotate
# 验证 PM2 安装
pm2 --version

# 创建 Python 3.11 的 Alpha 环境
echo "创建 Python 3.8.18 的 Alpha 环境..."
# 创建新的环境
conda create -n Alpha python==3.8.18 -y
# 激活环境
conda activate Alpha
# 安装ta-lib
conda install -c conda-forge ta-lib==0.4.19

# 验证 Python 版本
python --version

# 安装 requirements.txt
echo "安装 requirements.txt ..."
pip install -r https://raw.githubusercontent.com/evon16888/xiaobai/refs/heads/main/requirements.txt

# 安装Htop
echo "安装 Htop..."
sudo apt install htop -y

# ==========================================
# MySQL 安装与 GitHub 初始化脚本整合区域
# ==========================================
echo "[+] 开始安装与配置 MySQL..."

# 配置数据库变量（可在此处按需修改）
DB_NAME="alpha"
DB_USER="work"
DB_PASS="benji-perhaps-sally"   # 请修改为您的 MySQL 密码
INIT_SQL_URL="https://raw.githubusercontent.com/evon16888/xiaobai/refs/heads/main/init.sql" # 请替换为你的 init.sql 真实 Raw 链接
INIT_SQL_PATH="./init.sql"

export DEBIAN_FRONTEND=noninteractive
sudo apt install -y mysql-server mysql-client curl wget

# 启动并设置 MySQL 开机自启
sudo systemctl start mysql
sudo systemctl enable mysql

# 检查 MySQL 服务状态
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

# 检查下载是否成功
if [ ! -f "${INIT_SQL_PATH}" ] || [ ! -s "${INIT_SQL_PATH}" ]; then
  echo "[-] 错误: 初始化文件下载失败，请检查 URL 是否正确或网络是否畅通。"
  exit 1
fi

echo "[+] 正在执行数据库与用户初始化..."
sudo mysql -u root <<EOF
-- 创建数据库
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

-- 创建远程连接用户并授权
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF

echo "[+] 正在导入初始化文件到数据库 ${DB_NAME}..."
sudo mysql -u root "${DB_NAME}" < "${INIT_SQL_PATH}"
echo "[+] MySQL 初始化 SQL 导入成功！"

# 清理临时下载的 SQL 文件
rm -f "${INIT_SQL_PATH}"
# ==========================================

# 检查是否存在虚拟内存，Ubuntu 24.04.2 这个版本默认启用了 2G 的虚拟内存
if [ -f "/swap.img" ]; then
    # 停用旧的Swap
    sudo swapoff /swap.img
    # 删除原swap文件
    sudo rm /swap.img
fi
# 开始设置虚拟内存
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# 解决中文乱码
echo "开始安装字体"
cd /usr/share/fonts/
sudo wget https://github.com/adobe-fonts/source-han-sans/releases/download/2.004R/SourceHanSansSC.zip
sudo apt install unzip -y
sudo unzip SourceHanSansSC.zip
sudo mv OTF/ SourceHanSans/
sudo fc-cache –fv
rm -rf ~/.cache/matplotlib

# 完成
echo "miniconda3更节省硬盘空间、PM2、PM2日志管理工具、SourceHanSansSC字体、设置虚拟8G虚拟内存、Htop内存和CPU查看工具、MySQL及自动初始化、 Python 环境安装完成！"

# 启动新的交互式 shell，保持在虚拟环境中
exec $SHELL
