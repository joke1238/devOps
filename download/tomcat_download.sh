#!/bin/bash
# This script is used to download Apache Tomcat from the official website or Huawei mirror.
set -euo pipefail

TOMCAT_VERSION="10.1.55"
TOMCAT_MAJOR="10"
TOMCAT_URL="https://repo.huaweicloud.com/apache/tomcat/tomcat-${TOMCAT_MAJOR}/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
# 官方源（国内下载较慢，镜像不可用时切换）
# TOMCAT_URL="https://dlcdn.apache.org/tomcat/tomcat-${TOMCAT_MAJOR}/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
TAR_FILE="apache-tomcat-${TOMCAT_VERSION}.tar.gz"
INSTALL_DIR="/opt/tomcat"

echo "📦 创建安装目录..."
sudo mkdir -p "$INSTALL_DIR"

echo "⬇️  下载 Apache Tomcat v${TOMCAT_VERSION}..."
if command -v axel &>/dev/null; then
    sudo axel -n 8 -o "$TAR_FILE" "$TOMCAT_URL"
else
    sudo wget -O "$TAR_FILE" "$TOMCAT_URL"
fi

# 校验下载文件是否为有效的 gzip 格式
if ! file "$TAR_FILE" | grep -q "gzip compressed"; then
    echo "❌ 下载失败！文件不是有效的压缩包，请检查网络或镜像源。"
    echo "   实际文件类型: $(file "$TAR_FILE" | cut -d: -f2)"
    sudo rm -f "$TAR_FILE"
    exit 1
fi

echo "📂 解压到 $INSTALL_DIR..."
sudo tar -zxf "$TAR_FILE" -C "$INSTALL_DIR"

echo "🔗 创建软链接..."
sudo ln -sf "$INSTALL_DIR/apache-tomcat-${TOMCAT_VERSION}" "$INSTALL_DIR/current"

echo "🗑️  清理安装包..."
sudo rm -f "$TAR_FILE"

echo "✅ Apache Tomcat v${TOMCAT_VERSION} 安装到 $INSTALL_DIR/current 成功"
echo ""

# 检查 Java 环境
if command -v java &>/dev/null; then
    echo "☕ 检测到 Java 版本: $(java -version 2>&1 | head -1)"
else
    echo "⚠️  未检测到 Java，请先安装 JDK (Tomcat 10 需要 JDK 11+)"
fi

echo ""
echo "🚀 启动 Tomcat:"
echo "   $INSTALL_DIR/current/bin/startup.sh"
echo ""
echo "📋 停止 Tomcat:"
echo "   $INSTALL_DIR/current/bin/shutdown.sh"
echo ""
echo "💡 默认访问地址: http://localhost:8080"
echo "   默认管理用户配置: $INSTALL_DIR/current/conf/tomcat-users.xml"
