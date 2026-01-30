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
```

---

## 📖 详细部署教程

### 🟢 方案 A：CloudDrive2 + Emby (新手推荐)

**适用：** 阿里云盘 (Open)、115网盘、夸克网盘、123云盘。

**特点：** 配置极其简单，扫码登录即可。

#### 部署步骤

1. **运行脚本**：在菜单中选择 `1. 方案 A: CloudDrive2 + Emby`。

2. **绑定域名**：脚本最后会主动询问是否绑定域名和申请 SSL 证书，按需输入 `y` 并根据提示操作。

3. **配置网盘**：
   - 打开浏览器访问：`http://你的IP:19798` (如果你绑定了域名，直接访问域名即可)。
   - 注册并登录 CloudDrive2。
   - 点击图标扫码登录你的网盘（如 115 或 阿里云盘）。
   
   > [!WARNING]
   > **关键步骤** ⚠️：选中网盘后，点击界面上方的电脑图标（挂载），务必将挂载点名称手动修改为 `/CloudNAS`。
   > 
   > (注意：脚本默认将宿主机的挂载目录映射到了容器内的 `/CloudNAS`，名称不一致会导致 Emby 找不到文件)

4. **配置 Emby**：
   - 打开 Emby 后台（`http://你的IP:8096` 或域名）。
   - 添加媒体库 -> 文件夹选择器 -> `/mnt/media` -> 你会看到以你网盘命名的文件夹，选中即可。

---

### 🟡 方案 B：Alist + Emby (进阶性能)

**适用：** Google Drive、OneDrive、以及追求直链播放的用户。

**特点：** 播放流量不经过 VPS 中转，速度仅受本地宽带限制。

#### 部署步骤

1. **运行脚本**：选择 `2. 方案 B: Alist + Emby`。

2. **保存凭据**：
   
   > [!IMPORTANT]
   > 脚本运行结束后，屏幕底部会显示 **Alist 管理员账号** 和 **随机生成的安全密码**，请务必截图保存！

3. **配置 Alist**：
   - 打开 `http://你的IP:5244`，使用刚才保存的账号密码登录。
   - 在"存储"中添加你的网盘（如 Google Drive）。
   - **关键设置**：在网盘配置页面的 `WebDAV 策略` 选项中，选择 `302 重定向`。

4. **挂载到本地 (Rclone)**：
   - 脚本已自动安装 Rclone。你需要手动配置连接 Alist 的 WebDAV。
   - 在 SSH 输入 `rclone config` -> `n` (新建) -> 名字叫 `alist` -> 选择 `WebDAV 协议` -> 地址填 `http://127.0.0.1:5244/dav` -> 账号密码填 Alist 的 -> 确认。
   - 执行挂载命令（建议配合 `screen` 或 `systemd` 后台运行）：

   ```bash
   # 将 alist 挂载到脚本预设的目录
   rclone mount alist:/ /opt/media_stack/rclone_mount --copy-links --allow-other --allow-non-empty --vfs-cache-mode writes --daemon
   ```

5. **配置 Emby**：
   - 打开 Emby 后台，添加媒体库，路径选择 `/mnt/media` 即可。

---

## ⚙️ 端口说明

| 服务 | 默认端口 | 说明 |
|:---|:---:|:---|
| **Emby Server** | `8096` | 媒体服务器后台 |
| **CloudDrive2** | `19798` | 方案 A 的网盘管理后台 |
| **Alist** | `5244` | 方案 B 的网盘列表程序 |

---

## ⚠️ CentOS/RHEL 用户特别提示

CentOS 系统默认防火墙 (Firewalld) 可能会拦截外部访问。如果安装后无法访问网页后台，请执行以下命令放行端口：

```bash
# 放行常用端口
firewall-cmd --zone=public --add-port=8096/tcp --permanent
firewall-cmd --zone=public --add-port=19798/tcp --permanent
firewall-cmd --zone=public --add-port=5244/tcp --permanent
firewall-cmd --zone=public --add-port=80/tcp --permanent
firewall-cmd --zone=public --add-port=443/tcp --permanent

# 重载防火墙使配置生效
firewall-cmd --reload
```

---

## 🛠️ 常见问题 (FAQ)

### Q1: 自动 SSL 证书申请失败怎么办？

- 确保域名已经解析到当前服务器 IP。
- 确保 80 端口未被占用且防火墙已放行。
- 如果失败，可以再次运行脚本选择 `4. 单独安装/配置 Nginx + SSL` 重试。

### Q2: Emby 搜不到海报怎么办？

- 脚本已内置 TMDB Hosts 优化功能。如果在菜单中选择"安装"后依然不行，可以单独运行脚本选择 `"选项 3: 修复 TMDB Hosts"`。

### Q3: 如何卸载？

- 运行脚本，选择 `"选项 5: 卸载并清理"`。这将删除所有容器，并询问是否删除配置文件数据。

---

## 📝 免责声明

本脚本仅供学习交流使用。请勿用于非法用途。在使用 115、阿里云盘等服务时，请遵守相应服务商的使用条款。
