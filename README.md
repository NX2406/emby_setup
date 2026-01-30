# Emby 全能影音库一键部署脚本 (Universal Emby Cloud Setup) 🚀

[![OS](https://img.shields.io/badge/OS-CentOS%20%7C%20Ubuntu%20%7C%20Debian-blue)](https://github.com/NX2406/emby_setup)
[![Docker](https://img.shields.io/badge/Docker-Required-blue)](https://www.docker.com/)
[![Feature](https://img.shields.io/badge/SSL-Auto%20HTTPS-green)]()

> **专为网络工程师和影音爱好者打造的自动化部署工具。**
> 一键在 Linux VPS/NAS 上部署 Emby Media Server，自动挂载主流网盘，并集成 Nginx 反代与 SSL 证书自动申请。

## ✨ v3.4 核心特性

* **🐧 全系统适配**：自动识别并适配 **CentOS 7+**、**AlmaLinux**、**Ubuntu 20.04+**、**Debian 11+**。
* **🔐 安全强化**：
    * **Alist 随机密码**：方案 B 部署时自动生成 16 位高强度随机密码，杜绝弱口令风险。
    * **SSL 自动化**：集成 Certbot，支持一键申请 Let's Encrypt 免费证书并配置 HTTPS 强转。
* **🔄 双模部署架构**：
    * **方案 A (CloudDrive2)**：零门槛，像本地硬盘一样使用网盘，适合阿里云盘、115、夸克。
    * **方案 B (Alist + 直链)**：高性能模式，支持 302 重定向，适合 VPS 带宽较小或追求极致播放速度的场景。
* **🛠️ 自动化运维**：
    * 自动优化 TMDB Hosts，解决国内服务器海报刮削失败的问题。
    * 自动配置 Docker 挂载传递 (Mount Propagation)，解决网盘文件在 Emby 中不可见的问题。

## 🚀 快速开始

在你的服务器终端执行以下命令即可启动中文交互菜单：

```bash
bash <(curl -sL https://raw.githubusercontent.com/NX2406/emby_setup/refs/heads/main/setup_emby_cn.sh)
