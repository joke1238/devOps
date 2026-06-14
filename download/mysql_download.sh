#!/bin/bash
# This script is used to download and install MySQL Community Server from Oracle.
set -euo pipefail

# ============================================
# 配置区域 - 可根据需要修改
# ============================================
MYSQL_VERSION="8.4.8"
MYSQL_FULL_VERSION="mysql-${MYSQL_VERSION}-linux-glibc2.28-x86_64"
# 官方下载地址（dev.mysql.com/get 会重定向到 CDN）
MYSQL_URL="https://dev.mysql.com/get/Downloads/MySQL-8.4/${MYSQL_FULL_VERSION}.tar.xz"
# 备用官方 CDN（若上述地址失败）
MYSQL_CDN_URL="https://cdn.mysql.com/Downloads/MySQL-8.4/${MYSQL_FULL_VERSION}.tar.xz"
# 华为云镜像（国内下载更快）
MIRROR_URL="https://repo.huaweicloud.com/mysql/Downloads/MySQL-8.4/${MYSQL_FULL_VERSION}.tar.xz"
TAR_FILE="${MYSQL_FULL_VERSION}.tar.xz"
INSTALL_DIR="/opt/mysql"
DATA_DIR="${INSTALL_DIR}/data"

# MySQL root 密码（若为空则使用临时密码）
MYSQL_ROOT_PASSWORD=""

echo "========================================"
echo "   MySQL ${MYSQL_VERSION} 安装脚本"
echo "========================================"
echo ""

# ============================================
# 前置检查
# ============================================
echo "📋 前置检查..."

# 检查是否已安装
if [ -d "$INSTALL_DIR/current" ] && [ -f "$INSTALL_DIR/current/bin/mysqld" ]; then
    echo "⚠️  检测到 MySQL 已安装在 $INSTALL_DIR/current"
    read -p "是否覆盖安装？（输入 y 继续）: " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ 已取消安装"
        exit 1
    fi
    # 尝试停止已有服务
    if systemctl is-active --quiet mysql 2>/dev/null; then
        echo "⏹️  停止现有 MySQL 服务..."
        sudo systemctl stop mysql
    fi
fi

# 检查依赖
MISSING_DEPS=()
for cmd in wget tar xz file; do
    if ! command -v $cmd &>/dev/null; then
        MISSING_DEPS+=($cmd)
    fi
done

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo "❌ 缺少必要工具: ${MISSING_DEPS[*]}"
    echo "   请运行: sudo apt update && sudo apt install -y ${MISSING_DEPS[*]}"
    exit 1
fi

# 检查 libaio（MySQL 依赖）
if ! ldconfig -p | grep -q libaio 2>/dev/null && ! dpkg -l libaio1 &>/dev/null 2>&1; then
    echo "⚠️  建议安装 libaio: sudo apt install -y libaio1"
fi

echo "✅ 前置检查通过"
echo ""

# ============================================
# 创建系统用户和目录
# ============================================
echo "📦 创建安装目录和系统用户..."

# 创建 mysql 系统用户
if ! id -u mysql &>/dev/null; then
    sudo useradd -r -m -d /home/mysql -s /bin/bash mysql
    echo "👤 已创建 mysql 系统用户"
else
    echo "👤 mysql 系统用户已存在"
fi

# 创建安装和数据目录
sudo mkdir -p "$INSTALL_DIR"
sudo mkdir -p "$DATA_DIR"

echo "✅ 目录准备完成"
echo ""

# ============================================
# 下载 MySQL
# ============================================
echo "⬇️  下载 MySQL ${MYSQL_VERSION}..."

# 优先使用国内镜像
DOWNLOAD_SUCCESS=false
download_with() {
    local tool="$1" url="$2" label="$3"
    echo "   ⬇️  尝试 $label ..."
    if [ "$tool" = "axel" ]; then
        sudo axel -n 8 -o "$TAR_FILE" "$url" && DOWNLOAD_SUCCESS=true
    else
        sudo wget -O "$TAR_FILE" "$url" && DOWNLOAD_SUCCESS=true
    fi
}

DOWNLOAD_TOOL=""
if command -v axel &>/dev/null; then
    DOWNLOAD_TOOL="axel"
elif command -v wget &>/dev/null; then
    DOWNLOAD_TOOL="wget"
else
    echo "❌ 未找到 wget 或 axel"
    exit 1
fi

# 依次尝试：华为云镜像 → dev.mysql.com 官方 → cdn.mysql.com 备用
download_with "$DOWNLOAD_TOOL" "$MIRROR_URL" "华为云镜像" || true
if [ "$DOWNLOAD_SUCCESS" = false ]; then
    download_with "$DOWNLOAD_TOOL" "$MYSQL_URL" "官方源 dev.mysql.com" || true
fi
if [ "$DOWNLOAD_SUCCESS" = false ]; then
    download_with "$DOWNLOAD_TOOL" "$MYSQL_CDN_URL" "备用源 cdn.mysql.com" || true
fi
if [ "$DOWNLOAD_SUCCESS" = false ]; then
    echo "❌ 所有下载地址均失败！"
    echo "   可手动下载后放到当前目录:"
    echo "   wget $MYSQL_URL"
    exit 1
fi

# 校验下载文件
if [ ! -f "$TAR_FILE" ]; then
    echo "❌ 下载失败！文件未找到"
    exit 1
fi

if ! file "$TAR_FILE" | grep -q "XZ compressed"; then
    echo "❌ 下载失败！文件不是有效的 XZ 压缩包"
    echo "   实际文件类型: $(file "$TAR_FILE" | cut -d: -f2)"
    sudo rm -f "$TAR_FILE"
    exit 1
fi

echo "✅ 下载完成"
echo ""

# ============================================
# 解压安装
# ============================================
echo "📂 解压到 $INSTALL_DIR..."

sudo tar -Jxf "$TAR_FILE" -C "$INSTALL_DIR"

echo "🔗 创建软链接..."
sudo ln -sf "$INSTALL_DIR/$MYSQL_FULL_VERSION" "$INSTALL_DIR/current"

echo "🗑️  清理安装包..."
sudo rm -f "$TAR_FILE"

# 设置目录权限
echo "🔐 设置目录权限..."
sudo chown -R mysql:mysql "$INSTALL_DIR/"
sudo chmod 750 "$DATA_DIR"

echo "✅ 解压完成"
echo ""

# ============================================
# MySQL 配置
# ============================================
echo "⚙️  生成 my.cnf 配置文件..."

sudo tee /etc/my.cnf > /dev/null << EOF
[client]
port = 3306
socket = ${DATA_DIR}/mysql.sock
default-character-set = utf8mb4

[mysql]
default-character-set = utf8mb4
prompt = "\\\\u@\\\\h [\\\\d]> "

[mysqld]
# 基础路径
basedir = ${INSTALL_DIR}/current
datadir = ${DATA_DIR}
socket = ${DATA_DIR}/mysql.sock
pid-file = ${DATA_DIR}/mysqld.pid
log-error = ${DATA_DIR}/error.log

# 端口
port = 3306

# 字符集
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

# 连接
max_connections = 1000
max_connect_errors = 10000

# 默认存储引擎
default-storage-engine = INNODB

# InnoDB 配置
innodb_buffer_pool_size = 1G
innodb_log_file_size = 256M
innodb_flush_log_at_trx_commit = 1
innodb_file_per_table = 1

# SQL 模式
sql_mode = STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION

# 表名大小写（0=区分大小写，1=不区分）
lower_case_table_names = 1

# 时区
default-time-zone = '+8:00'

[mysqld_safe]
log-error = ${DATA_DIR}/error.log
pid-file = ${DATA_DIR}/mysqld.pid
EOF

echo "✅ 配置文件生成完成"
echo ""

# ============================================
# 初始化数据库
# ============================================
echo "🔧 初始化数据库..."
cd "$INSTALL_DIR/current"

# 如果数据目录已有文件，询问是否重新初始化
if [ -f "${DATA_DIR}/ibdata1" ]; then
    echo "⚠️  数据目录 $DATA_DIR 已有数据文件"
    read -p "是否删除旧数据并重新初始化？（输入 y 确认）: " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "⏭️  跳过数据库初始化"
    else
        sudo rm -rf "${DATA_DIR:?}/"*
        echo "♻️  已清空数据目录"
    fi
fi

# 初始化（如果数据目录为空才执行）
if [ ! -f "${DATA_DIR}/ibdata1" ]; then
    echo "⏳ 正在初始化数据库（这可能需要几分钟）..."

    # 记录临时密码
    TEMP_PASSWORD_FILE="${DATA_DIR}/temp_password.txt"
    sudo -u mysql "$INSTALL_DIR/current/bin/mysqld" --initialize \
        --basedir="$INSTALL_DIR/current" \
        --datadir="$DATA_DIR" \
        --user=mysql 2>"$TEMP_PASSWORD_FILE" || true

    # 提取临时密码
    TEMP_PASSWORD=""
    if [ -f "$TEMP_PASSWORD_FILE" ]; then
        TEMP_PASSWORD=$(grep -oP "A temporary password is generated for root@localhost: \K.*" "${DATA_DIR}/error.log" 2>/dev/null || echo "")
        if [ -z "$TEMP_PASSWORD" ]; then
            TEMP_PASSWORD=$(grep -oP "root@localhost: \K.*" "${DATA_DIR}/error.log" 2>/dev/null || echo "（未找到临时密码，请查看 ${DATA_DIR}/error.log）")
        fi
    fi

    echo "✅ 数据库初始化完成"
    echo ""
    echo "   🔑 root 临时密码: $TEMP_PASSWORD"
    echo ""
    echo "   ⚠️  请务必在首次登录后修改密码！"
    echo ""
fi

# 修改 mysql 库表的所有权（确保 mysql 系统表权限正确）
sudo chown -R mysql:mysql "$DATA_DIR"

echo ""

# ============================================
# 配置 systemd 服务
# ============================================
echo "⚙️  配置 systemd 服务..."

sudo tee /etc/systemd/system/mysql.service > /dev/null << 'EOF'
[Unit]
Description=MySQL Community Server
Documentation=man:mysqld(8)
Documentation=http://dev.mysql.com/doc/refman/en/using-systemd.html
After=network.target
After=syslog.target

[Service]
Type=notify
User=mysql
Group=mysql
ExecStart=/opt/mysql/current/bin/mysqld --defaults-file=/etc/my.cnf
ExecStartPre=/opt/mysql/current/bin/mysqld_pre_systemd
ExecStop=/opt/mysql/current/bin/mysqladmin shutdown
TimeoutSec=300
Restart=on-failure
RestartSec=10

# 安全限制
PrivateTmp=false
LimitNOFILE=65536
LimitNPROC=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF

# 创建 mysqld_pre_systemd 脚本（用于 systemd 启动前的准备工作）
sudo tee /opt/mysql/current/bin/mysqld_pre_systemd > /dev/null << 'SHEOF'
#!/bin/bash
# MySQL systemd 前置准备脚本
if [ ! -d /opt/mysql/data ]; then
    mkdir -p /opt/mysql/data
    chown mysql:mysql /opt/mysql/data
fi
exit 0
SHEOF
sudo chmod +x /opt/mysql/current/bin/mysqld_pre_systemd

sudo systemctl daemon-reload

echo "✅ systemd 服务配置完成"
echo ""

# ============================================
# 设置环境变量
# ============================================
echo "📝 配置环境变量..."
ENV_FILE="/etc/profile.d/mysql.sh"
sudo tee "$ENV_FILE" > /dev/null << EOF
export MYSQL_HOME=${INSTALL_DIR}/current
export PATH=\$MYSQL_HOME/bin:\$PATH
EOF
sudo chmod +x "$ENV_FILE"

echo "✅ 环境变量配置完成（重新登录后生效）"
echo ""

# ============================================
# 完成
# ============================================
echo ""
echo "========================================"
echo "   ✅ MySQL ${MYSQL_VERSION} 安装完成！"
echo "========================================"
echo ""
echo "📋 管理命令："
echo "====================================="
echo "🚀 启动:   sudo systemctl start mysql"
echo "⏹️  停止:   sudo systemctl stop mysql"
echo "🔄 重启:   sudo systemctl restart mysql"
echo "📊 状态:   sudo systemctl status mysql"
echo "📈 开机自启: sudo systemctl enable mysql"
echo "====================================="
echo ""
echo "🔑 登录数据库："
echo "   1. 先启动服务:   sudo systemctl start mysql"
echo "   2. 使用临时密码登录:"
echo "      mysql -u root -p"
echo "   3. 修改 root 密码:"
echo "      ALTER USER 'root'@'localhost' IDENTIFIED BY '新密码';"
echo "      FLUSH PRIVILEGES;"
echo ""
echo "📁 重要路径："
echo "   安装目录:   ${INSTALL_DIR}/current"
echo "   数据目录:   ${DATA_DIR}"
echo "   配置文件:   /etc/my.cnf"
echo "   错误日志:   ${DATA_DIR}/error.log"
echo ""
echo "🌐 端口: 3306 (默认)"
echo ""
echo "📌 注意事项："
echo "   1. 请立即登录修改 root 密码，防止安全隐患"
echo "   2. 如需远程访问，创建专用用户或修改 root 可远程登录"
echo "   3. 生产环境建议调整 innodb_buffer_pool_size 为物理内存的 70%"
echo "   4. MySQL 8.4 默认使用 caching_sha2_password 认证插件"
echo "   5. 环境变量已写入 /etc/profile.d/mysql.sh，重新登录后生效"
echo ""
echo "💡 快速启动："
echo "   source /etc/profile.d/mysql.sh"
echo "   sudo systemctl start mysql"
echo "   mysql -u root -p"
echo ""
