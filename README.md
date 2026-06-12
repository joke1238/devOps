# DevOps Shell Scripts

Shell 脚本工具库，用于 DevOps 日常操作和自动化任务。

## 目录

- [JDK 下载脚本](download/jdk_download.sh) — JDK 自动下载工具
- [Maven 下载脚本](download/maven_download.sh) — Maven 自动下载工具
- [Node.js 下载脚本](download/node_download.sh) — Node.js LTS 自动下载工具

## 使用方式

```bash
# 给脚本执行权限
chmod +x download/*.sh

# 运行脚本
./download/jdk_download.sh
```

## 环境要求

- Bash 4.0+
- 常用 Unix 工具（curl、wget、tar 等）
