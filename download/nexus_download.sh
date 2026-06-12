#!/bin/bash
# This script is used to download Sonatype Nexus Repository OSS from the official website.
set -euo pipefail

NEXUS_URL="https://download.sonatype.com/nexus/3/latest-unix.tar.gz"
TAR_FILE="nexus-latest-unix.tar.gz"
INSTALL_DIR="/opt/nexus"

echo "📦 创建安装目录..."
sudo mkdir -p "$INSTALL_DIR"

echo "⬇️  下载 Nexus Repository OSS..."
sudo wget -O "$TAR_FILE" "$NEXUS_URL"

echo "📂 解压到 $INSTALL_DIR..."
EXTRACT_DIR=$(sudo tar -tzf "$TAR_FILE" | head -1 | cut -d/ -f1)
sudo tar -zxf "$TAR_FILE" -C "$INSTALL_DIR"

echo "🔗 创建软链接..."
sudo ln -sf "$INSTALL_DIR/$EXTRACT_DIR" "$INSTALL_DIR/current"

echo "🧹 清理安装包..."
sudo rm -f "$TAR_FILE"

# 默认 sonatype-work 会解压到当前目录，移动到 INSTALL_DIR 下
if [ -d "sonatype-work" ]; then
    sudo mv sonatype-work "$INSTALL_DIR/"
fi

echo "✅ Nexus Repository OSS 安装到 $INSTALL_DIR/current 成功"
echo ""
echo "🚀 启动 Nexus 服务:"
echo "   $INSTALL_DIR/current/bin/nexus start"
echo ""
echo "📋 查看 Nexus 状态:"
echo "   $INSTALL_DIR/current/bin/nexus status"
echo ""
echo "🔧 停止 Nexus 服务:"
echo "   $INSTALL_DIR/current/bin/nexus stop"
echo ""
echo "💡 请确保已安装 JDK 17+，并将 Nexus 添加为 systemd 服务以获得更好的管理体验"
echo "   NEXUS_HOME=$INSTALL_DIR/current"
echo "   默认管理地址: http://localhost:8081"
echo "   默认管理员账号: admin"
