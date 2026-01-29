# Emby 全能影音库一键部署脚本 (Universal Emby Cloud Setup) 🚀

[![OS](https://img.shields.io/badge/OS-CentOS%20%7C%20Ubuntu%20%7C%20Debian-blue)](https://github.com/yourusername/emby-cloud-setup)
[![Docker](https://img.shields.io/badge/Docker-Required-blue)](https://www.docker.com/)
[![Language](https://img.shields.io/badge/Language-Bash-green)]()

> **专为网络工程师和影音爱好者打造的自动化部署工具。** > 一键在 Linux VPS/NAS 上部署 Emby Media Server，并自动挂载主流网盘（115、阿里云盘、夸克、Google Drive 等）。

## ✨ 核心特性

* **🐧 全系统适配**：自动识别并适配 **CentOS 7+**、**AlmaLinux**、**Ubuntu 20.04+**、**Debian 11+**。
* **🔄 双模部署架构**：
    * **方案 A (CloudDrive2)**：零门槛，像本地硬盘一样使用网盘，适合阿里云盘、115、夸克。
    * **方案 B (Alist + 直链)**：高性能模式，支持 302 重定向，适合 VPS 带宽较小或追求极致播放速度的场景。
* **🛠️ 自动化运维**：
    * 自动检测并安装 Docker 环境。
    * 自动解决国内服务器 TMDB 无法连接（海报刮削失败）的问题。
    * 自动配置 Docker 挂载传递 (Mount Propagation)，解决网盘文件不可见问题。

## 🚀 快速开始

在你的服务器终端执行以下命令即可启动中文交互菜单：

```bash
# 请将下面的 URL 替换为你 GitHub 仓库的真实 Raw 地址
bash <(curl -sL [https://raw.githubusercontent.com/你的用户名/仓库名/main/setup_emby_cn.sh](https://raw.githubusercontent.com/你的用户名/仓库名/main/setup_emby_cn.sh))
