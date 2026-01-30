# Emby 全能影音库一键部署脚本 (Universal Emby Cloud Setup) 🚀

[![OS](https://img.shields.io/badge/OS-CentOS%20%7C%20Ubuntu%20%7C%20Debian-blue)](https://github.com/NX2406/emby_setup)
[![Docker](https://img.shields.io/badge/Docker-Required-blue)](https://www.docker.com/)
[![Language](https://img.shields.io/badge/Language-Bash-green)]()

> **专为网络工程师和影音爱好者打造的自动化部署工具。**
> 一键在 Linux VPS/NAS 上部署 Emby Media Server，自动挂载主流网盘，并提供域名绑定指引。

## ✨ 核心特性

* **🐧 全系统适配**：自动识别并适配 **CentOS 7+**、**AlmaLinux**、**Ubuntu 20.04+**、**Debian 11+**。
* **🔄 双模部署架构**：
    * **方案 A (CloudDrive2)**：零门槛，像本地硬盘一样使用网盘，适合阿里云盘、115、夸克。
    * **方案 B (Alist + 直链)**：高性能模式，支持 302 重定向，适合 VPS 带宽较小或追求极致播放速度的场景。
* **🌐 域名绑定助手**：部署结束后主动询问，自动生成 Nginx 反代配置模板，助您轻松实现 `http://emby.yourdomain.com` 优雅访问。
* **🛠️ 自动化运维**：
    * 自动检测并安装 Docker 环境。
    * 自动优化 TMDB Hosts，解决国内服务器海报刮削失败的问题。
    * 自动配置 Docker 挂载传递 (Mount Propagation)，彻底解决网盘文件在 Emby 中不可见的问题。

## 🚀 快速开始

在你的服务器终端执行以下命令即可启动中文交互菜单：

```bash
bash <(curl -sL https://raw.githubusercontent.com/NX2406/emby_setup/refs/heads/main/setup_emby_cn.sh)
