#!/bin/bash
# This script is used to download Node.js LTS from the official website.
set -euo pipefail

NODE_VERSION="24.16.0"
NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.gz"
TAR_FILE="node-v${NODE_VERSION}-linux-x64.tar.gz"
INSTALL_DIR="/opt/node"

echo "📦 创建安装目录..."
sudo mkdir -p "$INSTALL_DIR"

echo "⬇️  下载 Node.js v${NODE_VERSION} LTS..."
sudo wget -O "$TAR_FILE" "$NODE_URL"

echo "📂 解压到 $INSTALL_DIR..."
sudo tar -zxf "$TAR_FILE" -C "$INSTALL_DIR"

echo "🔗 创建软链接..."
sudo ln -sf "$INSTALL_DIR/node-v${NODE_VERSION}-linux-x64" "$INSTALL_DIR/current"

echo "🧹 清理安装包..."
sudo rm -f "$TAR_FILE"

echo "✅ Node.js v${NODE_VERSION} LTS 安装到 $INSTALL_DIR/current 成功"
echo "💡 请将以下内容添加到 ~/.bashrc 或 ~/.zshrc："
echo "   export NODE_HOME=$INSTALL_DIR/current"
echo "   export PATH=\$NODE_HOME/bin:\$PATH"
