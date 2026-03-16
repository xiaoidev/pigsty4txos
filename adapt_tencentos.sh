#!/bin/bash
#==============================================================#
# File      :   adapt_tencentos.sh
# Desc      :   Adapt TencentOS 3.1 for Pigsty v4.0.0
# Ctime     :   2025-01-15
# Mtime     :   2025-01-15
# License   :   Apache-2.0
#==============================================================#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[ OK ]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[FAIL]${NC} $*"; }
log_hint()  { echo -e "${BLUE}[HINT]${NC} $*"; }

# 检查是否为 root 用户
if [[ $EUID -ne 0 ]]; then
   log_error "此脚本需要 root 权限执行"
   log_hint "请使用: sudo $0"
   exit 1
fi

# 检查是否为 TencentOS
if [[ ! -f /etc/os-release ]]; then
    log_error "找不到 /etc/os-release 文件"
    exit 1
fi

. /etc/os-release
ORIGINAL_ID="$ID"
ORIGINAL_VERSION_ID="$VERSION_ID"
ORIGINAL_NAME="$NAME"

echo ""
echo "============================================================"
echo "  TencentOS 3.1 -> Pigsty v4.0.0 适配脚本"
echo "============================================================"
echo ""

log_info "检测到系统信息:"
log_info "  NAME        = $ORIGINAL_NAME"
log_info "  ID          = $ORIGINAL_ID"
log_info "  VERSION_ID  = $ORIGINAL_VERSION_ID"
echo ""

# 检查是否为 TencentOS
if [[ "$ORIGINAL_ID" != "tencentos" ]]; then
    log_warn "当前系统不是 TencentOS (ID=$ORIGINAL_ID)"
    read -p "是否继续适配? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "已取消适配"
        exit 0
    fi
fi

# 检查版本是否为 3.x
if [[ "$ORIGINAL_VERSION_ID" != 3* ]]; then
    log_warn "TencentOS 版本不是 3.x (VERSION_ID=$ORIGINAL_VERSION_ID)"
    log_warn "此脚本仅适用于 TencentOS 3.x (基于 EL8)"
    read -p "是否继续适配? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "已取消适配"
        exit 0
    fi
fi

# 备份原始文件
backup_file="/etc/os-release.bak.$(date +%Y%m%d%H%M%S)"
cp /etc/os-release "$backup_file"
log_info "已备份原始文件到: $backup_file"

# 创建适配后的 os-release
cat > /etc/os-release << EOF
NAME="TencentOS Server"
VERSION="3.1 (Compatible with EL8 for Pigsty)"
ID="rocky"
ID_LIKE="rhel centos fedora tencentos"
VERSION_ID="8.6"
PLATFORM_ID="platform:el8"
PRETTY_NAME="TencentOS Server 3.1 (EL8 Compatible)"
ANSI_COLOR="0;31"
CPE_NAME="cpe:/o:rocky:rocky:8"
HOME_URL="https://tlinux.tencent.com/"
BUG_REPORT_URL="https://tlinux.tencent.com/"
ROCKY_SUPPORT_PRODUCT="Rocky Linux"
ROCKY_SUPPORT_PRODUCT_VERSION="8"
EOF

log_info "已修改 /etc/os-release"
echo ""

# 验证修改
. /etc/os-release
log_info "验证结果:"
log_info "  ID          = $ID"
log_info "  VERSION_ID  = $VERSION_ID"
log_info "  PRETTY_NAME = $PRETTY_NAME"
echo ""

# 检查包管理器
if command -v dnf &> /dev/null; then
    log_info "包管理器: dnf (EL8 兼容)"
elif command -v yum &> /dev/null; then
    log_info "包管理器: yum (EL8 兼容)"
else
    log_error "未找到 dnf 或 yum"
    exit 1
fi

# 检查架构
ARCH=$(uname -m)
log_info "系统架构: $ARCH"
echo ""

echo "============================================================"
log_info "TencentOS 3.1 适配完成!"
echo "============================================================"
echo ""
echo "后续步骤:"
echo ""
echo "  1. 上传 EL8 离线包到服务器:"
echo "     scp pigsty-pkg-v4.0.0.el8.x86_64.tgz root@server:/tmp/pkg.tgz"
echo ""
echo "  2. 下载 Pigsty 源码:"
echo "     curl -fsSL https://repo.pigsty.io/get | bash -s v4.0.0"
echo ""
echo "  3. 进入目录并执行 Bootstrap:"
echo "     cd ~/pigsty"
echo "     ./bootstrap -p /tmp/pkg.tgz"
echo ""
echo "  4. 配置并部署:"
echo "     ./configure -g"
echo "     ./deploy.yml"
echo ""
echo "  5. 访问 Web 界面:"
echo "     http://<server-ip>"
echo ""
echo "============================================================"
log_info "如需恢复原始配置: cp $backup_file /etc/os-release"
echo "============================================================"
