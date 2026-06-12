#!/bin/bash
# This script is used to download the JDK from the official Oracle website.
set -euo pipefail

JDK_URL="https://download.oracle.com/java/26/latest/jdk-26_linux-x64_bin.tar.gz"
TAR_FILE="jdk-26_linux-x64_bin.tar.gz"
INSTALL_DIR="/opt/java"

echo "📦 创建安装目录..."
sudo mkdir -p "$INSTALL_DIR"

echo "⬇️  下载 JDK 26..."
sudo wget -O "$TAR_FILE" "$JDK_URL"

echo "📂 解压到 $INSTALL_DIR..."
sudo tar -zxf "$TAR_FILE" -C "$INSTALL_DIR"

echo "🧹 清理安装包..."
sudo rm -f "$TAR_FILE"

echo "✅ JDK 26 下载并安装到 $INSTALL_DIR 成功"