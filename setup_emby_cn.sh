#!/bin/bash

# ==============================================================================
# 项目名称: Emby 全能影音库一键部署脚本 (CN版 v3.5 - 全自动挂载版)
# 脚本作者: 网络工程师
# 功能描述: Docker Emby + 网盘挂载 + Nginx + SSL + 自动Rclone配置与挂载
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
SSL_SUCCESS="false"

# 生成 16 位高强度随机密码 (排除特殊字符以免破坏 Rclone 命令格式，仅留字母数字，安全性足够)
RANDOM_PWD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
ALIST_USER="admin"

# --- 基础工具函数 ---

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
        yum install -y epel-release
        yum update -y
        yum install -y curl wget tar net-tools fuse
    elif [ -f /etc/debian_version ]; then
        PACKAGE_MANAGER="apt"
        echo -e "${YELLOW}>>> 检测到 Debian/Ubuntu 系统，正在安装基础依赖...${NC}"
        apt-get update
        apt-get install -y curl wget tar net-tools fuse
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

# --- Nginx 自动化配置模块 ---

install_nginx() {
    if ! command -v nginx &> /dev/null; then
        echo -e "${YELLOW}>>> 正在安装 Nginx...${NC}"
        if [ "$PACKAGE_MANAGER" == "yum" ]; then
            yum install -y nginx
        else
            apt-get install -y nginx
        fi
        systemctl enable nginx
        systemctl start nginx
        echo -e "${GREEN}>>> Nginx 安装完成${NC}"
    else
        echo -e "${GREEN}>>> Nginx 已安装${NC}"
    fi
}

configure_nginx_automation() {
    echo -e ""
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}       🌐 Nginx 域名自动配置助手       ${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo -e "本功能将自动安装 Nginx 并配置反向代理。"
    echo -e "前提条件: 您已将域名解析到本服务器 IP: ${HOST_IP}"
    echo -e "------------------------------------------------"
    
    read -p "是否启用 Nginx 自动配置？(y/n): " nginx_choice
    
    if [[ "$nginx_choice" == "y" || "$nginx_choice" == "Y" ]]; then
        install_nginx
        
        read -p "请输入您的域名 (例如 emby.test.com): " user_domain
        if [ -z "$user_domain" ]; then
            echo -e "${RED}域名不能为空，跳过配置。${NC}"
            return
        fi
        
        DOMAIN_NAME="$user_domain"
        CONF_PATH="/etc/nginx/conf.d/emby.conf"
        if [ -d "/etc/nginx/sites-enabled" ]; then
             rm -f /etc/nginx/sites-enabled/default
        fi

        echo -e "${YELLOW}>>> 正在写入 Nginx 配置...${NC}"
        
        cat > "$CONF_PATH" <<EOF
server {
    listen 80;
    server_name ${DOMAIN_NAME};

    location / {
        proxy_pass http://127.0.0.1:${EMBY_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        client_max_body_size 0;
    }
}
EOF
        
        nginx -t
        if [ $? -eq 0 ]; then
            systemctl reload nginx
            echo -e "${GREEN}>>> Nginx 配置成功！${NC}"
            
            echo -e ""
            read -p "是否自动申请 HTTPS 证书 (免费)? (y/n): " ssl_choice
            if [[ "$ssl_choice" == "y" || "$ssl_choice" == "Y" ]]; then
                echo -e "${YELLOW}>>> 正在安装 Certbot...${NC}"
                if [ "$PACKAGE_MANAGER" == "yum" ]; then
                    yum install -y certbot python3-certbot-nginx
                else
                    apt-get install -y certbot python3-certbot-nginx
                fi
                
                echo -e ""
                read -p "请输入您的邮箱 (用于接收通知): " cert_email
                if [ -z "$cert_email" ]; then
                    echo -e "${RED}邮箱为空，跳过 SSL。${NC}"
                else
                    echo -e "${YELLOW}>>> 正在申请证书 (静默模式)...${NC}"
                    certbot --nginx --non-interactive --agree-tos --redirect --email "$cert_email" -d "${DOMAIN_NAME}"
                    if [ $? -eq 0 ]; then
                        echo -e "${GREEN}>>> HTTPS 配置完成！${NC}"
                        SSL_SUCCESS="true"
                    else
                        echo -e "${RED}>>> 证书申请失败。${NC}"
                    fi
                fi
            fi
        else
            echo -e "${RED}>>> Nginx 配置检测失败。${NC}"
        fi
    else
        echo -e "已跳过 Nginx 配置。"
    fi
}

# --- 最终信息展示 ---
show_final_info() {
    local scheme_name="$1"
    
    echo -e ""
    echo -e "${GREEN}########################################################${NC}"
    echo -e "${GREEN}#           🎉 恭喜！部署完成 (方案: ${scheme_name})             #${NC}"
    echo -e "${GREEN}########################################################${NC}"
    echo -e ""
    
    if [ "$scheme_name" == "方案A" ]; then
        echo -e "${YELLOW}1. 配置网盘 (CloudDrive2)${NC}"
        echo -e "   访问地址:  http://${HOST_IP}:${CD2_PORT}"
        echo -e "   ${RED}>>> 务必去 CD2 后台将网盘挂载到 /CloudNAS${NC}"
        echo -e ""
    fi

    if [ "$scheme_name" == "方案B" ]; then
        echo -e "${YELLOW}1. 配置网盘 (Alist)${NC}"
        echo -e "   访问地址:  http://${HOST_IP}:${ALIST_PORT}"
        echo -e "   -----------------------------------------------------"
        echo -e "   ${CYAN}管理员账号:  ${ALIST_USER}${NC}"
        echo -e "   ${CYAN}安全密码:    ${RANDOM_PWD}${NC}"
        echo -e "   ${RED}(请立即截图保存！)${NC}"
        echo -e "   -----------------------------------------------------"
        echo -e "   ${GREEN}>>> 脚本已自动为您配置好 Rclone 挂载！${NC}"
        echo -e "   ${GREEN}>>> 您只需去 Alist 添加网盘，Emby 即可看到文件。${NC}"
        echo -e ""
    fi

    echo -e "${YELLOW}2. 访问影音服 (Emby Server)${NC}"
    if [ "$SSL_SUCCESS" == "true" ]; then
        echo -e "   ${CYAN}域名访问:  https://${DOMAIN_NAME}${NC}"
    elif [ -n "$DOMAIN_NAME" ]; then
        echo -e "   ${CYAN}域名访问:  http://${DOMAIN_NAME}${NC}"
    else
        echo -e "   IP访问:    http://${HOST_IP}:${EMBY_PORT}"
    fi
    echo -e "   媒体库路径: /mnt/media/[你的网盘名称]"
    echo -e ""
    echo -e "${GREEN}########################################################${NC}"
}

# --- 方案 A: CloudDrive2 ---
install_scheme_a() {
    echo -e "${BLUE}>>> 正在部署方案 A...${NC}"
    install_base_dependencies
    install_docker
    fix_tmdb_hosts

    docker rm -f clouddrive2 emby &> /dev/null
    mkdir -p "$WORK_DIR/clouddrive2/config"
    mkdir -p "$WORK_DIR/clouddrive2/mount"
    mkdir -p "$WORK_DIR/emby/config"

    docker run -d --name clouddrive2 --restart unless-stopped --privileged --device /dev/fuse:/dev/fuse -v "$WORK_DIR/clouddrive2/mount":/CloudNAS:shared -v "$WORK_DIR/clouddrive2/config":/Config -p ${CD2_PORT}:19798 cloudnas/clouddrive2
    docker run -d --name emby --restart unless-stopped --net=host --privileged -e UID=0 -e GID=0 -v "$WORK_DIR/emby/config":/config -v "$WORK_DIR/clouddrive2/mount":/mnt/media:shared emby/embyserver:latest

    configure_nginx_automation
    show_final_info "方案A"
}

# --- 方案 B: Alist ---
install_scheme_b() {
    echo -e "${BLUE}>>> 正在部署方案 B...${NC}"
    install_base_dependencies
    install_docker
    install_rclone
    fix_tmdb_hosts

    # 1. 清理环境
    docker rm -f alist emby &> /dev/null
    # 强制卸载挂载点以防残留
    umount /opt/media_stack/rclone_mount 2>/dev/null
    
    mkdir -p "$WORK_DIR/alist"
    mkdir -p "$WORK_DIR/emby/config"
    mkdir -p "$WORK_DIR/rclone_mount"

    # 2. 启动 Alist
    docker run -d --restart=always -v "$WORK_DIR/alist":/opt/alist/data -p ${ALIST_PORT}:5244 -e PUID=0 -e PGID=0 -e UMASK=022 --name="alist" xhofe/alist:latest
    
    # 3. 自动配置 Alist 密码
    echo -e "${YELLOW}>>> 正在配置 Alist 安全策略...${NC}"
    sleep 5 # 等待容器启动
    docker exec alist ./alist admin set "$RANDOM_PWD" &> /dev/null
    
    # 4. [新功能] 自动配置 Rclone 连接并挂载
    echo -e "${YELLOW}>>> 正在自动配置 Rclone 连接...${NC}"
    # 等待 Alist 端口完全就绪
    sleep 5
    
    # 使用 rclone config create 非交互式创建配置
    # 注意：这里我们使用本地环回地址连接 Alist，速度最快
    rclone config create alist webdav url="http://127.0.0.1:5244/dav" vendor="other" user="admin" pass="$RANDOM_PWD" --non-interactive
    
    echo -e "${YELLOW}>>> 正在挂载 Alist 到本地...${NC}"
    # 后台挂载
    rclone mount alist:/ /opt/media_stack/rclone_mount --copy-links --allow-other --allow-non-empty --vfs-cache-mode writes --daemon
    
    # 5. 启动 Emby
    docker run -d --name emby --restart unless-stopped --net=host --privileged -e UID=0 -e GID=0 -v "$WORK_DIR/emby/config":/config -v "$WORK_DIR/rclone_mount":/mnt/media:shared emby/embyserver:latest

    configure_nginx_automation
    show_final_info "方案B"
}

# --- 主菜单 ---
show_menu() {
    clear
    echo -e "${CYAN}################################################${NC}"
    echo -e "${CYAN}#     Emby 全能影音库一键构建脚本 (v3.5)       #${NC}"
    echo -e "${CYAN}#     新增: Rclone 全自动配置与挂载 (零手动)   #${NC}"
    echo -e "${CYAN}################################################${NC}"
    echo -e ""
    echo -e "请选择部署方案:"
    echo -e "------------------------------------------------"
    echo -e "${GREEN}1. 方案 A: CloudDrive2 + Emby${NC}"
    echo -e "   (推荐: 阿里云盘/115/夸克 - 含 Nginx 自动配置)"
    echo -e ""
    echo -e "${YELLOW}2. 方案 B: Alist + Emby${NC}"
    echo -e "   (推荐: Google Drive/直链播放 - 含 Nginx 自动配置)"
    echo -e "   ${RED}* 包含自动高强密码 + 自动挂载，无需手动配置 Rclone${NC}"
    echo -e ""
    echo -e "------------------------------------------------"
    echo -e "实用工具箱:"
    echo -e "3. 修复 TMDB Hosts"
    echo -e "4. 单独安装/配置 Nginx + SSL"
    echo -e "5. 卸载并清理"
    echo -e "0. 退出"
    echo -e "------------------------------------------------"
    read -p "请输入数字 [0-5]: " choice

    case $choice in
        1) check_root; install_scheme_a ;;
        2) check_root; install_scheme_b ;;
        3) check_root; fix_tmdb_hosts ;;
        4) check_root; install_base_dependencies; configure_nginx_automation ;;
        5)
            echo -e "${RED}正在清理...${NC}"
            docker rm -f clouddrive2 alist emby &> /dev/null
            systemctl stop nginx &> /dev/null
            # 尝试卸载挂载点
            umount /opt/media_stack/rclone_mount 2>/dev/null
            read -p "删除配置文件? (y/n): " del_conf
            if [ "$del_conf" == "y" ]; then rm -rf "$WORK_DIR"; fi
            echo "完成。"
            ;;
        0) exit 0 ;;
        *) echo "输入错误"; sleep 1; show_menu ;;
    esac
}

show_menu
