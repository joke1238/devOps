#!/bin/bash
# This script is used to download Maven from the official Apache website.
set -euo pipefail

MAVEN_VERSION="3.9.9"
MAVEN_URL="https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz"
TAR_FILE="apache-maven-${MAVEN_VERSION}-bin.tar.gz"
INSTALL_DIR="/opt/maven"

echo "📦 创建安装目录..."
sudo mkdir -p "$INSTALL_DIR"

echo "⬇️  下载 Maven ${MAVEN_VERSION}..."
sudo wget -O "$TAR_FILE" "$MAVEN_URL"

echo "📂 解压到 $INSTALL_DIR..."
sudo tar -zxf "$TAR_FILE" -C "$INSTALL_DIR"

echo "🔗 创建软链接..."
sudo ln -sf "$INSTALL_DIR/apache-maven-${MAVEN_VERSION}" "$INSTALL_DIR/current"

echo "🧹 清理安装包..."
sudo rm -f "$TAR_FILE"

echo "✅ Maven ${MAVEN_VERSION} 安装到 $INSTALL_DIR/current 成功"
echo "💡 请将以下内容添加到 ~/.bashrc 或 ~/.zshrc："
echo "   export MAVEN_HOME=$INSTALL_DIR/current"
echo "   export PATH=\$MAVEN_HOME/bin:\$PATH"
