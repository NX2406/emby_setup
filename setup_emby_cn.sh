#!/bin/bash

# ==============================================================================
# 项目名称: Emby 全能影音库一键部署脚本 (中文通用版)
# 脚本作者: 网络工程师
# 功能描述: 基于 Docker 一键部署 Emby + 网盘挂载 (支持 115/阿里云盘/夸克/Google Drive 等)
# 兼容系统: CentOS 7+, AlmaLinux, Rocky Linux, Ubuntu 20.04+, Debian 11+
# ==============================================================================

# --- 颜色定义 (让输出更好看) ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- 全局配置 ---
# 基础工作目录 (所有配置和挂载都在这里，方便管理)
WORK_DIR="/opt/media_stack"
HOST_IP=$(curl -s ifconfig.me)

# --- 工具函数 ---

# 1. 检查 Root 权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[错误] 请使用 root 权限运行此脚本 (输入 sudo -i 切换)${NC}"
        exit 1
    fi
}

# 2. 系统检测与基础依赖安装 (适配 CentOS/Ubuntu)
install_base_dependencies() {
    if [ -f /etc/redhat-release ]; then
        # CentOS / RHEL 系列
        PACKAGE_MANAGER="yum"
        echo -e "${YELLOW}>>> 检测到 CentOS/RHEL 系统，正在安装基础依赖...${NC}"
        yum update -y
        yum install -y curl wget tar
    elif [ -f /etc/debian_version ]; then
        # Debian / Ubuntu 系列
        PACKAGE_MANAGER="apt"
        echo -e "${YELLOW}>>> 检测到 Debian/Ubuntu 系统，正在安装基础依赖...${NC}"
        apt-get update
        apt-get install -y curl wget tar
    else
        echo -e "${RED}[错误] 不支持的操作系统，请使用 CentOS, Ubuntu 或 Debian。${NC}"
        exit 1
    fi
}

# 3. 安装 Docker (通用脚本)
install_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}>>> 未检测到 Docker，正在自动安装...${NC}"
        
        # 使用官方通用脚本安装
        curl -fsSL https://get.docker.com | bash
        
        # 启动 Docker 并设置开机自启
        systemctl enable docker
        systemctl start docker
        
        echo -e "${GREEN}>>> Docker 安装完成${NC}"
    else
        echo -e "${GREEN}>>> Docker 已安装，跳过${NC}"
    fi
}

# 4. 修复 TMDB Hosts (解决海报刮削失败)
fix_tmdb_hosts() {
    echo -e "${YELLOW}>>> 正在优化 TMDB Hosts (解决国内无法刮削海报)...${NC}"
    cp /etc/hosts /etc/hosts.bak
    # 删除旧记录
    sed -i '/api.themoviedb.org/d' /etc/hosts
    sed -i '/image.tmdb.org/d' /etc/hosts
    # 写入优选 IP (建议定期检查更新)
    echo "18.160.41.69 api.themoviedb.org" >> /etc/hosts
    echo "13.224.161.90 image.tmdb.org" >> /etc/hosts
    echo -e "${GREEN}>>> Hosts 优化完成${NC}"
    # 如果 Emby 在运行，重启它
    if docker ps | grep -q emby; then docker restart emby > /dev/null; fi
}

# 5. 安装 Rclone
install_rclone() {
    if ! command -v rclone &> /dev/null; then
        echo -e "${YELLOW}>>> 正在安装 Rclone (用于方案 B)...${NC}"
        curl https://rclone.org/install.sh | sudo bash
        echo -e "${GREEN}>>> Rclone 安装完成${NC}"
    else
        echo -e "${GREEN}>>> Rclone 已安装${NC}"
    fi
}

# --- 方案 A: CloudDrive2 (新手推荐/通用挂载) ---
install_scheme_a() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}   正在部署方案 A: CloudDrive2 + Emby    ${NC}"
    echo -e "${BLUE}   适配: 115/阿里云/夸克/123/Google等    ${NC}"
    echo -e "${BLUE}=========================================${NC}"

    install_base_dependencies
    install_docker

    # 1. 清理
    docker rm -f clouddrive2 emby &> /dev/null

    # 2. 目录准备
    mkdir -p "$WORK_DIR/clouddrive2/config"
    mkdir -p "$WORK_DIR/clouddrive2/mount"
    mkdir -p "$WORK_DIR/emby/config"

    # 3. 部署 CD2
    echo -e "${YELLOW}>>> 启动 CloudDrive2 容器...${NC}"
    docker run -d \
      --name clouddrive2 \
      --restart unless-stopped \
      --privileged \
      --device /dev/fuse:/dev/fuse \
      -v "$WORK_DIR/clouddrive2/mount":/CloudNAS:shared \
      -v "$WORK_DIR/clouddrive2/config":/Config \
      -p 19798:19798 \
      cloudnas/clouddrive2

    # 4. 部署 Emby
    echo -e "${YELLOW}>>> 启动 Emby 容器...${NC}"
    docker run -d \
      --name emby \
      --restart unless-stopped \
      --net=host \
      --privileged \
      -e UID=0 -e GID=0 \
      -v "$WORK_DIR/emby/config":/config \
      -v "$WORK_DIR/clouddrive2/mount":/mnt/media:shared \
      emby/embyserver:latest

    echo -e "${GREEN}>>> 方案 A 部署完成！${NC}"
    echo -e "------------------------------------------------"
    echo -e "1. 配置 CD2:   http://${HOST_IP}:19798"
    echo -e "   -> 登录你的网盘 (115/阿里/夸克等)"
    echo -e "   -> ${RED}关键步骤: 将网盘挂载到 /CloudNAS 目录${NC}"
    echo -e ""
    echo -e "2. 配置 Emby:  http://${HOST_IP}:8096"
    echo -e "   -> 添加媒体库路径: /mnt/media/[你的网盘名]"
    echo -e "------------------------------------------------"
}

# --- 方案 B: Alist + Emby (进阶/高性能直链) ---
install_scheme_b() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE} 正在部署方案 B: Alist + Emby + 302直链  ${NC}"
    echo -e "${BLUE} 适配: 所有 Alist 支持的网盘 (性能最强)  ${NC}"
    echo -e "${BLUE}=========================================${NC}"
    
    install_base_dependencies
    install_docker

    # 1. 清理
    docker rm -f alist emby &> /dev/null

    # 2. 目录
    mkdir -p "$WORK_DIR/alist"
    mkdir -p "$WORK_DIR/emby/config"
    mkdir -p "$WORK_DIR/rclone_mount"

    # 3. 部署 Alist
    echo -e "${YELLOW}>>> 启动 Alist 容器...${NC}"
    docker run -d \
      --restart=always \
      -v "$WORK_DIR/alist":/opt/alist/data \
      -p 5244:5244 \
      -e PUID=0 -e PGID=0 -e UMASK=022 \
      --name="alist" \
      xhofe/alist:latest

    # 4. 部署 Emby (指向未来的 Rclone 挂载点)
    echo -e "${YELLOW}>>> 启动 Emby 容器...${NC}"
    docker run -d \
      --name emby \
      --restart unless-stopped \
      --net=host \
      --privileged \
      -e UID=0 -e GID=0 \
      -v "$WORK_DIR/emby/config":/config \
      -v "$WORK_DIR/rclone_mount":/mnt/media:shared \
      emby/embyserver:latest

    echo -e "${GREEN}>>> 方案 B 容器就绪！(还需手动配置)${NC}"
    echo -e "------------------------------------------------"
    echo -e "后续步骤 (网络工程师进阶):"
    echo -e "1. 访问 Alist (http://${HOST_IP}:5244) 添加网盘。"
    echo -e "2. 使用 rclone config 连接 Alist 的 WebDAV。"
    echo -e "3. 将 WebDAV 挂载到: ${WORK_DIR}/rclone_mount"
    echo -e "   (可使用脚本菜单中的 '安装 Rclone' 功能)"
    echo -e "------------------------------------------------"
}

# --- 主菜单 ---
show_menu() {
    clear
    echo -e "${CYAN}################################################${NC}"
    echo -e "${CYAN}#     Emby 全能影音库一键构建脚本 (CN版)       #${NC}"
    echo -e "${CYAN}#     支持: CentOS / Ubuntu / Debian           #${NC}"
    echo -e "${CYAN}################################################${NC}"
    echo -e ""
    echo -e "请选择部署方案:"
    echo -e "------------------------------------------------"
    echo -e "${GREEN}1. 方案 A: CloudDrive2 + Emby${NC}"
    echo -e "   (新手推荐: 阿里云盘/115/夸克/123盘 - 配置最简单)"
    echo -e ""
    echo -e "${YELLOW}2. 方案 B: Alist + Emby (需配合Rclone/直链)${NC}"
    echo -e "   (进阶玩家: 追求极致播放速度/VPS带宽较小)"
    echo -e ""
    echo -e "------------------------------------------------"
    echo -e "实用工具箱:"
    echo -e "3. 修复 TMDB Hosts (解决海报不显示)"
    echo -e "4. 安装 Rclone (方案B必备)"
    echo -e "5. 查看当前挂载状态 (调试用)"
    echo -e "6. 卸载并清理所有容器"
    echo -e "0. 退出"
    echo -e "------------------------------------------------"
    read -p "请输入数字 [0-6]: " choice

    case $choice in
        1)
            check_root
            install_scheme_a
            fix_tmdb_hosts
            ;;
        2)
            check_root
            install_scheme_b
            fix_tmdb_hosts
            install_rclone
            ;;
        3)
            check_root
            fix_tmdb_hosts
            ;;
        4)
            install_rclone
            ;;
        5)
            echo -e "${BLUE}>>> 宿主机挂载目录 ($WORK_DIR) 内容:${NC}"
            ls -lhR "$WORK_DIR" | grep ":$" | head -n 10
            echo -e "..."
            ;;
        6)
            echo -e "${RED}正在删除所有相关容器和数据...${NC}"
            docker rm -f clouddrive2 alist emby &> /dev/null
            read -p "是否同时删除配置文件和缓存? (y/n): " del_conf
            if [ "$del_conf" == "y" ]; then
                rm -rf "$WORK_DIR"
                echo "配置文件已删除。"
            fi
            echo "清理完成。"
            ;;
        0)
            exit 0
            ;;
        *)
            echo "输入错误，按回车重试..."
            read
            show_menu
            ;;
    esac
}

# --- 运行 ---
show_menu
