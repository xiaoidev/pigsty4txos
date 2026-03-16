# TencentOS 3.1 适配 Pigsty v4.0.0 指南

## 概述

TencentOS 3.1 基于 RHEL 8，与 EL8 (Enterprise Linux 8) 完全兼容。但 Pigsty 的操作系统检测逻辑无法直接识别 TencentOS，需要进行适配。

---

## 快速适配脚本

将以下脚本保存为 `adapt_tencentos.sh` 并执行：

```bash
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
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# 检查是否为 root 用户
if [[ $EUID -ne 0 ]]; then
   log_error "此脚本需要 root 权限执行"
   exit 1
fi

# 检查是否为 TencentOS
if [[ ! -f /etc/os-release ]]; then
    log_error "找不到 /etc/os-release 文件"
    exit 1
fi

. /etc/os-release

if [[ "$ID" != "tencentos" ]]; then
    log_warn "当前系统不是 TencentOS (ID=$ID)"
    log_info "如果确定要继续，请手动修改脚本"
    read -p "是否继续? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        exit 0
    fi
fi

log_info "检测到 TencentOS $VERSION_ID"

# 备份原始文件
backup_file="/etc/os-release.bak.$(date +%Y%m%d%H%M%S)"
cp /etc/os-release "$backup_file"
log_info "已备份原始文件到: $backup_file"

# 创建适配后的 os-release
cat > /etc/os-release << 'EOF'
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

# 验证修改
. /etc/os-release
log_info "验证结果:"
log_info "  ID = $ID"
log_info "  VERSION_ID = $VERSION_ID"
log_info "  PRETTY_NAME = $PRETTY_NAME"

# 检查包管理器
if command -v dnf &> /dev/null; then
    log_info "包管理器: dnf (EL8 兼容)"
elif command -v yum &> /dev/null; then
    log_info "包管理器: yum (EL8 兼容)"
else
    log_error "未找到 dnf 或 yum"
    exit 1
fi

log_info "============================================"
log_info "TencentOS 3.1 适配完成!"
log_info "现在可以使用 EL8 离线包安装 Pigsty:"
log_info ""
log_info "  1. 上传离线包: pigsty-pkg-v4.0.0.el8.x86_64.tgz"
log_info "  2. 下载源码: curl -fsSL https://repo.pigsty.io/get | bash -s v4.0.0"
log_info "  3. 进入目录: cd ~/pigsty"
log_info "  4. Bootstrap: ./bootstrap -p /tmp/pkg.tgz"
log_info "  5. 配置: ./configure -g"
log_info "  6. 部署: ./deploy.yml"
log_info ""
log_info "如需恢复原始配置: cp $backup_file /etc/os-release"
log_info "============================================"
```

---

## 手动适配步骤

### 步骤 1: 备份原始配置

```bash
sudo cp /etc/os-release /etc/os-release.bak
```

### 步骤 2: 修改 os-release

```bash
sudo tee /etc/os-release > /dev/null << 'EOF'
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
```

### 步骤 3: 验证修改

```bash
. /etc/os-release
echo "ID=$ID, VERSION_ID=$VERSION_ID"
# 应输出: ID=rocky, VERSION_ID=8.6
```

### 步骤 4: 安装 Pigsty

```bash
# 下载源码
curl -fsSL https://repo.pigsty.io/get | bash -s v4.0.0
cd ~/pigsty

# 使用 EL8 离线包
./bootstrap -p /tmp/pkg.tgz

# 配置
./configure -g

# 部署
./deploy.yml
```

---

## 恢复原始配置

如需恢复 TencentOS 原始标识：

```bash
sudo cp /etc/os-release.bak /etc/os-release
```

或重新安装 `tencentos-release` 包：

```bash
sudo dnf reinstall tencentos-release -y
```

---

## 注意事项

1. **软件包兼容性**: TencentOS 3.1 的软件包与 EL8 完全兼容，Pigsty 的 EL8 离线包可以直接使用。

2. **内核版本**: TencentOS 3.1 使用 5.4 内核，高于标准 EL8 的 4.18，完全满足要求。

3. **生产环境**: 建议在测试环境验证后再部署到生产环境。

4. **系统更新**: 修改 os-release 后，系统更新可能会覆盖此文件，需要重新适配。

---

## 常见问题

### Q: 为什么需要修改 os-release？

A: Pigsty 根据操作系统 ID 和 VERSION_ID 来选择对应的配置文件和软件包。TencentOS 的 ID 是 "tencentos"，VERSION_ID 是 "3.1"，Pigsty 无法识别，会尝试加载不存在的配置文件。

### Q: 修改后会影响系统功能吗？

A: 不会。这只是修改了系统标识信息，不影响实际的软件包管理和系统功能。TencentOS 3.1 本身就是基于 RHEL 8 构建的。

### Q: 可以使用在线安装吗？

A: 可以。如果没有离线包，可以使用在线安装：
```bash
./bootstrap  # 不指定 -p 参数
```
Pigsty 会自动配置 EL8 的软件源。

---

## 文件清单

| 文件 | 说明 |
|------|------|
| `/etc/os-release` | 系统标识文件 (需修改) |
| `/etc/os-release.bak` | 原始文件备份 |
| `pigsty-pkg-v4.0.0.el8.x86_64.tgz` | EL8 离线安装包 |

---

## 相关链接

- [Pigsty 官方文档](https://pigsty.io/docs/)
- [Pigsty GitHub](https://github.com/pgsty/pigsty)
- [TencentOS 官方文档](https://tlinux.tencent.com/)
