#!/bin/bash
# This script is used to download and install RabbitMQ from GitHub releases.
set -euo pipefail

RABBITMQ_VERSION="4.3.0"
RABBITMQ_URL="https://github.com/rabbitmq/rabbitmq-server/releases/download/v${RABBITMQ_VERSION}/rabbitmq-server-generic-unix-${RABBITMQ_VERSION}.tar.xz"
# 官方镜像（国内下载较慢）
# RABBITMQ_URL="https://github.com/rabbitmq/rabbitmq-server/releases/download/v${RABBITMQ_VERSION}/rabbitmq-server-generic-unix-${RABBITMQ_VERSION}.tar.xz"
TAR_FILE="rabbitmq-server-generic-unix-${RABBITMQ_VERSION}.tar.xz"
INSTALL_DIR="/opt/rabbitmq"

echo "📋 前置检查..."

# 检查 Erlang
if ! command -v erl &>/dev/null; then
    echo "⚠️  未检测到 Erlang/OTP，RabbitMQ 4.x 需要 Erlang 26+"
    echo "   安装 Erlang: sudo apt install erlang -y"
    echo "   或: sudo apt install erlang-base erlang-nox -y"
    echo ""
    read -p "是否继续安装 RabbitMQ？（可能启动失败，输入 y 继续）: " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ 已取消安装"
        exit 1
    fi
else
    echo "☕ 检测到 Erlang: $(erl -version 2>&1)"
fi

echo "📦 创建安装目录..."
sudo mkdir -p "$INSTALL_DIR"

echo "⬇️  下载 RabbitMQ v${RABBITMQ_VERSION}..."
if command -v axel &>/dev/null; then
    sudo axel -n 8 -o "$TAR_FILE" "$RABBITMQ_URL"
else
    sudo wget -O "$TAR_FILE" "$RABBITMQ_URL"
fi

# 校验下载文件是否为有效的 xz 格式
if ! file "$TAR_FILE" | grep -q "XZ compressed"; then
    echo "❌ 下载失败！文件不是有效的压缩包，请检查网络。"
    echo "   实际文件类型: $(file "$TAR_FILE" | cut -d: -f2)"
    sudo rm -f "$TAR_FILE"
    exit 1
fi

echo "📂 解压到 $INSTALL_DIR..."
sudo tar -Jxf "$TAR_FILE" -C "$INSTALL_DIR"

# 解压后的目录名
EXTRACT_DIR="rabbitmq_server-${RABBITMQ_VERSION}"

echo "🔗 创建软链接..."
sudo ln -sf "$INSTALL_DIR/$EXTRACT_DIR" "$INSTALL_DIR/current"

echo "🗑️  清理安装包..."
sudo rm -f "$TAR_FILE"

# 创建 rabbitmq 系统用户
echo "👤 创建 rabbitmq 系统用户..."
sudo useradd -r -m -d /home/rabbitmq -s /bin/bash rabbitmq 2>/dev/null || true

# 修改所有权
sudo chown -R rabbitmq:rabbitmq "$INSTALL_DIR/"

echo "✅ RabbitMQ v${RABBITMQ_VERSION} 安装到 $INSTALL_DIR/current 成功"
echo ""

# 启用管理插件
echo "🔌 启用 Management 管理控制台插件..."
sudo -u rabbitmq RABBITMQ_HOME="$INSTALL_DIR/current" "$INSTALL_DIR/current/sbin/rabbitmq-plugins" enable rabbitmq_management 2>/dev/null || echo "   ⚠️  插件启用失败，可在启动后再执行"

# 设置 systemd 服务
echo "⚙️  配置 systemd 服务..."
sudo tee /etc/systemd/system/rabbitmq.service > /dev/null << 'EOF'
[Unit]
Description=RabbitMQ Message Broker
After=network.target

[Service]
Type=simple
User=rabbitmq
Group=rabbitmq
Environment=HOME=/home/rabbitmq
Environment=RABBITMQ_HOME=/opt/rabbitmq/current
ExecStart=/opt/rabbitmq/current/sbin/rabbitmq-server
ExecStop=/opt/rabbitmq/current/sbin/rabbitmqctl stop
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload

echo ""
echo "📋 RabbitMQ 管理命令："
echo "====================================="
echo "🚀 启动:   sudo systemctl start rabbitmq"
echo "⏹️  停止:   sudo systemctl stop rabbitmq"
echo "🔄 重启:   sudo systemctl restart rabbitmq"
echo "📊 状态:   sudo systemctl status rabbitmq"
echo "====================================="
echo ""
echo "🌐 管理控制台: http://localhost:15672"
echo "   AMQP 端口:  5672"
echo "   默认账号:   guest / guest"
echo ""
echo "💡 手动管理插件:"
echo "   sudo -u rabbitmq /opt/rabbitmq/current/sbin/rabbitmq-plugins list"
echo ""
echo "📌 注意："
echo "   1. guest 用户只能从 localhost 登录"
echo "   2. 如需远程访问，创建新用户或修改 guest 配置"
echo "   3. RabbitMQ 4.x 需要 Erlang/OTP 26+"
