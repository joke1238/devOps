#!/bin/bash
# This script is used to download the JDK from the official Oracle website.
mkdir -p /opt/java
sudo wget -O  https://download.oracle.com/java/26/latest/jdk-26_linux-x64_bin.tar.gz
sudo tar -zxvf jdk-26_linux-x64_bin.tar.gz -C /opt/java
sudo rm jdk-26_linux-x64_bin.tar.gz
echo "jdk downloaded and extracted to /opt/java/jdk-26 ----successfully"