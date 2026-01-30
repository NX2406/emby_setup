#!/bin/bash

# ==============================================================================
# 项目名称: Emby 全能影音库一键部署脚本 (中文通用版 v2.0)
# 脚本作者: 网络工程师
# 功能描述: Docker 部署 Emby + 网盘挂载 + 域名绑定助手
# 兼容系统: CentOS 7+, Ubuntu 20.04+, Debian 11+
# ==============================================================================

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- 全局配置 ---
WORK_DIR="/opt/media_stack"
HOST_IP=$(curl -s ifconfig.me)
EMBY_PORT=8096
CD2_PORT=19798
ALIST_PORT=5244
DOMAIN_NAME=""

# --- 工具函数 ---

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[错误] 请使用 root 权限运行此脚本 (输入 sudo -i 切换)${NC}"
        exit 1
    fi
}

install_base_dependencies() {
    if [ -f /etc/redhat-release ]; then
        PACKAGE_MANAGER="yum"
        echo -e "${YELLOW}>>> 检测到 CentOS/RHEL 系统，正在安装基础依赖...${NC}"
        yum update -y
        yum install -y curl wget tar
    elif [ -f /etc/debian_version ]; then
        PACKAGE_MANAGER="apt"
        echo -e "${YELLOW}>>> 检测到 Debian/Ubuntu 系统，正在安装基础依赖...${NC}"
        apt-get update
        apt-get install -y curl wget tar
    else
        echo -e "${RED}[错误] 不支持的操作系统。${NC}"
        exit 1
    fi
}

install_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}>>> 未检测到 Docker，正在自动安装...${NC}"
        curl -fsSL https://get.docker.com | bash
        systemctl enable docker
        systemctl start docker
        echo -e "${GREEN}>>> Docker 安装完成${NC}"
    else
        echo -e "${GREEN}>>> Docker 已安装，跳过${NC}"
    fi
}

fix_tmdb_hosts() {
    echo -e "${YELLOW}>>> 正在优化 TMDB Hosts...${NC}"
    cp /etc/hosts /etc/hosts.bak
    sed -i '/api.themoviedb.org/d' /etc/hosts
    sed -i '/image.tmdb.org/d' /etc/hosts
    echo "18.160.41.69 api.themoviedb.org" >> /etc/hosts
    echo "13.224.161.90 image.tmdb.org" >> /etc/hosts
    echo -e "${GREEN}>>> Hosts 优化完成${NC}"
    if docker ps | grep -q emby; then docker restart emby > /dev/null; fi
}

install_rclone() {
    if ! command -v rclone &> /dev/null; then
        echo -e "${YELLOW}>>> 正在安装 Rclone...${NC}"
        curl https://rclone.org/install.sh | sudo bash
        echo -e "${GREEN}>>> Rclone 安装完成${NC}"
    else
        echo -e "${GREEN}>>> Rclone 已安装${NC}"
    fi
}

# --- 域名绑定助手 (新增功能) ---
ask_domain_binding() {
    echo -e ""
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}       🌐 域名绑定助手 (可选步骤)       ${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo -e "您是否拥有一个域名，并希望通过域名访问 Emby？"
    echo -e "例如: http://emby.yourdomain.com -> 访问本机的 8096 端口"
    echo -e "${YELLOW}注意: 您需要先在域名服务商处将域名 A 记录解析到本服务器 IP: ${HOST_IP}${NC}"
    echo -e "------------------------------------------------"
    
    read -p "是否需要绑定域名？(y/n): " bind_choice
    
    if [[ "$bind_choice" == "y" || "$bind_choice" == "Y" ]]; then
        read -p "请输入您的域名 (例如 emby.test.com): " user_domain
        if [ -z "$user_domain" ]; then
            echo -e "${RED}域名不能为空，跳过绑定。${NC}"
            DOMAIN_NAME=""
        else
            DOMAIN_NAME="$user_domain"
            echo -e "${GREEN}>>> 已记录域名: ${DOMAIN_NAME}${NC}"
            
            # 生成 Nginx 配置模板
            echo -e "${YELLOW}>>> 正在为您生成 Nginx 反向代理配置建议...${NC}"
            echo -e ""
            echo -e "${BLUE}--- Nginx 配置文件参考 (emby.conf) ---${NC}"
            echo "server {"
            echo "    listen 80;"
            echo "    server_name ${DOMAIN_NAME};"
            echo "    location / {"
            echo "        proxy_pass http://127.0.0.1:${EMBY_PORT};"
            echo "        proxy_set_header Host \$host;"
            echo "        proxy_set_header X-Real-IP \$remote_addr;"
            echo "        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;"
            echo "        # WebSocket 支持 (Emby 必需)"
            echo "        proxy_http_version 1.1;"
            echo "        proxy_set_header Upgrade \$http_upgrade;"
            echo "        proxy_set_header Connection \"upgrade\";"
            echo "    }"
            echo "}"
            echo -e "${BLUE}--------------------------------------${NC}"
            echo -e "提示: 请将上述内容添加到您的 Nginx 配置文件中并重载 Nginx。"
            echo -e "如果您使用的是 Nginx Proxy Manager，请直接在后台添加 Proxy Host。"
            echo -e ""
            read -p "按回车键继续..."
        fi
    else
        echo -e "已跳过域名绑定。"
        DOMAIN_NAME=""
    fi
}

# --- 最终信息展示 (优化版) ---
show_final_info() {
    local scheme_name="$1"
    
    echo -e ""
    echo -e "${GREEN}########################################################${NC}"
    echo -e "${GREEN}#           🎉 恭喜！部署完成 (方案: ${scheme_name})             #${NC}"
    echo -e "${GREEN}########################################################${NC}"
    echo -e ""
    
    # 1. CloudDrive2 (仅方案A)
    if [ "$scheme_name" == "方案A" ]; then
        echo -e "${YELLOW}1. 配置网盘 (CloudDrive2)${NC}"
        echo -e "   -----------------------------------------------------"
        echo -e "   访问地址:  http://${HOST_IP}:${CD2_PORT}"
        echo -e "   操作指南:  登录网盘 -> ${RED}必须将网盘挂载到 /CloudNAS 目录${NC}"
        echo -e ""
    fi

    # 2. Alist (仅方案B)
    if [ "$scheme_name" == "方案B" ]; then
        echo -e "${YELLOW}1. 配置网盘 (Alist)${NC}"
        echo -e "   -----------------------------------------------------"
        echo -e "   访问地址:  http://${HOST_IP}:${ALIST_PORT}"
        echo -e "   操作指南:  添加网盘 -> 获取 WebDAV 信息 -> 配置 Rclone"
        echo -e ""
    fi

    # 3. Emby Server (通用)
    echo -e "${YELLOW}2. 访问影音服 (Emby Server)${NC}"
    echo -e "   -----------------------------------------------------"
    if [ -n "$DOMAIN_NAME" ]; then
        echo -e "   ${CYAN}域名访问:  http://${DOMAIN_NAME} (需自行配置Nginx)${NC}"
        echo -e "   IP访问:    http://${HOST_IP}:${EMBY_PORT}"
    else
        echo -e "   访问地址:  http://${HOST_IP}:${EMBY_PORT}"
    fi
    echo -e "   -----------------------------------------------------"
    echo -e "   ${BLUE}媒体库设置路径:${NC}"
    if [ "$scheme_name" == "方案A" ]; then
        echo -e "   /mnt/media/[你的网盘名称]"
    else
        echo -e "   /mnt/media (对应你的 Rclone 挂载点)"
    fi
    echo -e ""
    echo -e "${GREEN}########################################################${NC}"
    echo -e "Enjoy your private theater! 🎬"
}

# --- 方案 A: CloudDrive2 ---
install_scheme_a() {
    echo -e "${BLUE}>>> 正在部署方案 A...${NC}"
    install_base_dependencies
    install_docker

    docker rm -f clouddrive2 emby &> /dev/null
    mkdir -p "$WORK_DIR/clouddrive2/config"
    mkdir -p "$WORK_DIR/clouddrive2/mount"
    mkdir -p "$WORK_DIR/emby/config"

    docker run -d --name clouddrive2 --restart unless-stopped --privileged --device /dev/fuse:/dev/fuse -v "$WORK_DIR/clouddrive2/mount":/CloudNAS:shared -v "$WORK_DIR/clouddrive2/config":/Config -p ${CD2_PORT}:19798 cloudnas/clouddrive2
    docker run -d --name emby --restart unless-stopped --net=host --privileged -e UID=0 -e GID=0 -v "$WORK_DIR/emby/config":/config -v "$WORK_DIR/clouddrive2/mount":/mnt/media:shared emby/embyserver:latest

    ask_domain_binding
    show_final_info "方案A"
}

# --- 方案 B: Alist ---
install_scheme_b() {
    echo -e "${BLUE}>>> 正在部署方案 B...${NC}"
    install_base_dependencies
    install_docker

    docker rm -f alist emby &> /dev/null
    mkdir -p "$WORK_DIR/alist"
    mkdir -p "$WORK_DIR/emby/config"
    mkdir -p "$WORK_DIR/rclone_mount"

    docker run -d --restart=always -v "$WORK_DIR/alist":/opt/alist/data -p ${ALIST_PORT}:5244 -e PUID=0 -e PGID=0 -e UMASK=022 --name="alist" xhofe/alist:latest
    docker run -d --name emby --restart unless-stopped --net=host --privileged -e UID=0 -e GID=0 -v "$WORK_DIR/emby/config":/config -v "$WORK_DIR/rclone_mount":/mnt/media:shared emby/embyserver:latest

    ask_domain_binding
    show_final_info "方案B"
}

# --- 主菜单 ---
show_menu() {
    clear
    echo -e "${CYAN}################################################${NC}"
    echo -e "${CYAN}#     Emby 全能影音库一键构建脚本 (CN版 v2.0)  #${NC}"
    echo -e "${CYAN}#     支持: CentOS / Ubuntu / Debian           #${NC}"
    echo -e "${CYAN}################################################${NC}"
    echo -e ""
    echo -e "请选择部署方案:"
    echo -e "------------------------------------------------"
    echo -e "${GREEN}1. 方案 A: CloudDrive2 + Emby${NC}"
    echo -e "   (新手推荐: 阿里云盘/115/夸克/123盘)"
    echo -e ""
    echo -e "${YELLOW}2. 方案 B: Alist + Emby${NC}"
    echo -e "   (进阶玩家: 追求极致速度/直链播放)"
    echo -e ""
    echo -e "------------------------------------------------"
    echo -e "实用工具箱:"
    echo -e "3. 修复 TMDB Hosts"
    echo -e "4. 安装 Rclone"
    echo -e "5. 卸载并清理"
    echo -e "0. 退出"
    echo -e "------------------------------------------------"
    read -p "请输入数字 [0-5]: " choice

    case $choice in
        1) check_root; install_scheme_a; fix_tmdb_hosts ;;
        2) check_root; install_scheme_b; fix_tmdb_hosts; install_rclone ;;
        3) check_root; fix_tmdb_hosts ;;
        4) install_rclone ;;
        5)
            echo -e "${RED}正在清理...${NC}"
            docker rm -f clouddrive2 alist emby &> /dev/null
            read -p "删除配置文件? (y/n): " del_conf
            if [ "$del_conf" == "y" ]; then rm -rf "$WORK_DIR"; fi
            echo "完成。"
            ;;
        0) exit 0 ;;
        *) echo "输入错误"; sleep 1; show_menu ;;
    esac
}

show_menu
