# Pigsty v4 on TencentOS 3.1 自动化部署

在 Windows Hyper-V 上自动化创建 3 台 TencentOS Server 3.1 虚拟机，通过 Kickstart 完成无人值守安装，并内置操作系统适配，用于部署 [Pigsty](https://pigsty.io/) v4 三节点高可用集群。

Pigsty 是开箱即用的 PostgreSQL 发行版（PostgreSQL In Great STYle），提供高可用、备份恢复、监控告警和可视化运维能力。TencentOS Server 3.1 基于 RHEL 8（EL8 兼容）构建，Pigsty 的系统检测逻辑无法直接识别其发行版标识，因此本工程通过改写 `/etc/os-release` 将其伪装为 Rocky Linux 8.6 来完成适配。

## 特性

- **一键创建虚拟机：** 自动创建外部虚拟交换机、第 2 代虚拟机和动态虚拟硬盘，并开启嵌套虚拟化。
- **Kickstart 无人值守：** 每个节点一份独立配置，自动完成分区、软件包安装、SSH 与 sudo 配置。
- **适配内置：** Kickstart 安装后脚本自动改写 `/etc/os-release`，系统装完即可通过 Pigsty 的 EL8 检测。
- **三节点规划：** 1 个 meta 节点 + 2 个 replica 节点，对应 Pigsty 一主两从高可用拓扑。
- **故障诊断：** 附带 Hyper-V 一键修复与中/英文诊断脚本，覆盖「虚拟机监控程序未运行」等常见问题。

## 集群规划

| 节点 | IP | 角色 | CPU | 内存 | 磁盘 |
|------|----|------|-----|------|------|
| pigsty-node1 | 192.168.1.11 | meta（主节点） | 4 核 | 8 GB | 100 GB |
| pigsty-node2 | 192.168.1.12 | replica（从节点） | 4 核 | 8 GB | 100 GB |
| pigsty-node3 | 192.168.1.13 | replica（从节点） | 4 核 | 8 GB | 100 GB |

默认系统配置如下：

- 时区 `Asia/Shanghai`，键盘布局 `us`
- root 与 admin 用户的默认密码均为 `Pigsty@2024`（仅限实验环境，生产环境请务必修改）
- 防火墙关闭，SELinux 设为 permissive 模式
- 仓库内 `ks/*.cfg` 默认使用 DHCP；`create_pigsty_vms_auto.ps1` 可生成静态 IP 版本

## 环境要求

- Windows 10/11 专业版/企业版或 Windows Server，已启用 Hyper-V
- 以管理员身份运行 PowerShell
- TencentOS Server 3.1 安装镜像：`TencentOS-Server-3.1-20240925.0-TK4-x86_64-minimal.iso`
- 宿主机建议保留 24 GB 以上可用内存、300 GB 以上磁盘空间（动态磁盘，实际占用随用量增长）
- 已在 BIOS/UEFI 中开启硬件虚拟化（Intel VT-x / AMD-V）和硬件数据执行保护（XD / NX）

> **注意：** 脚本中的默认 ISO 与 Kickstart 路径为 `v4_txos`，请通过 `-ISOPath`、`-KSPath`、`-VMPath` 等参数替换为本机实际路径。

## 快速开始

### 1. 修复 Hyper-V

以管理员身份打开 PowerShell，执行快速修复脚本：

```powershell
.\quick_fix_hyperv.ps1
```

脚本会启用 Hyper-V 功能、设置虚拟机监控程序开机自启，并检测运行状态。如果提示需要重启，请进入 BIOS/UEFI 开启 VT-x 与 XD 后**完全关机再开机**（不要只重启）。

### 2. 创建虚拟机

方式一：仅创建虚拟机，随后手动安装系统：

```powershell
.\create_pigsty_vms.ps1 -ISOPath "D:\ISO\TencentOS-Server-3.1-minimal.iso"
```

方式二（推荐）：创建虚拟机并同时生成每节点的 Kickstart 文件：

```powershell
.\create_vms.ps1 -ISOPath "D:\ISO\TencentOS-Server-3.1-minimal.iso" -KSPath ".\ks"
```

方式三：生成静态 IP 版本的 Kickstart（中文日志输出）：

```powershell
.\create_pigsty_vms_auto.ps1 -ISOPath "D:\ISO\TencentOS-Server-3.1-minimal.iso" -KSPath ".\ks"
```

如遇 PowerShell 执行策略拦截，可使用：

```powershell
powershell -ExecutionPolicy Bypass -File .\create_vms.ps1
```

### 3. 通过 Kickstart 自动安装系统

在宿主机上启动 HTTP 服务，对外提供 Kickstart 文件：

```powershell
cd .\ks
python -m http.server 8080
```

启动虚拟机并打开控制台：

```powershell
Start-VM -Name 'pigsty-node1','pigsty-node2','pigsty-node3'
vmconnect.exe localhost pigsty-node1
```

在 GRUB 启动菜单中按 `e` 编辑启动项，在 `linuxefi` 行末尾追加 Kickstart 地址，然后按 `Ctrl + X` 启动：

```text
inst.ks=http://<宿主机IP>:8080/pigsty-node1.cfg
```

3 个节点分别替换为对应的 `pigsty-node1.cfg`、`pigsty-node2.cfg`、`pigsty-node3.cfg`。单节点安装约需 5～10 分钟，完成后会自动重启。

> **提示：** 可通过 `Get-NetIPAddress` 查看宿主机在虚拟交换机上的 IP，并确认防火墙放行 8080 端口。更多安装方式（自定义 ISO、PXE 等）请参考 [自动安装指南](./auto_install_guide.md)。

### 4. 验证安装结果

```bash
ssh root@192.168.1.11      # 密码：Pigsty@2024

# Kickstart 已完成 os-release 适配，预期输出 ID=rocky、VERSION_ID=8.6
. /etc/os-release && echo "$ID $VERSION_ID"

ip addr                    # 检查网络
systemctl status sshd      # 检查 SSH 服务
```

### 5. 适配 TencentOS（按需）

使用 Kickstart 安装的节点已自动完成适配，无需重复执行。手动安装的系统或适配被系统更新覆盖时，在节点内执行：

```bash
sudo ./adapt_tencentos.sh
```

脚本会先备份原始文件（形如 `/etc/os-release.bak.20250115103000`），再写入 EL8 兼容标识。需要还原时执行 `cp <备份文件> /etc/os-release`。原理与手动步骤详见 [TencentOS 适配指南](./tencentos_adapt.md)。

### 6. 部署 Pigsty

在 meta 节点上下载源码并执行部署：

```bash
# 下载 Pigsty 源码
curl -fsSL https://repo.pigsty.cc/get | bash

cd ~/pigsty
./bootstrap -p /tmp/pkg.tgz   # 有 EL8 离线包时指定包路径；在线安装直接执行 ./bootstrap
./configure -g                # 生成配置
./deploy.yml                  # 执行部署
```

部署完成后访问 `http://192.168.1.11` 进入 Web 界面。在线安装的完整步骤可参考 [Pigsty EL8 安装指南](./pigsty_el8_install.md)。

## 脚本说明

| 脚本 | 运行环境 | 说明 |
|------|----------|------|
| `quick_fix_hyperv.ps1` | 宿主机 | 启用 Hyper-V、设置监控程序自启并检测状态 |
| `diagnose_hyperv.ps1` | 宿主机 | Hyper-V 完整诊断工具（中文） |
| `diagnose_hyperv_en.ps1` | 宿主机 | Hyper-V 完整诊断工具（英文） |
| `create_pigsty_vms.ps1` | 宿主机 | 创建交换机和 3 台虚拟机，手动安装系统 |
| `create_vms.ps1` | 宿主机 | 创建虚拟机并生成 DHCP 版 Kickstart（英文） |
| `create_pigsty_vms_auto.ps1` | 宿主机 | 创建虚拟机并生成静态 IP 版 Kickstart（中文） |
| `setup_auto_install.ps1` | 宿主机 | 生成 Kickstart、解压 ISO、注入 GRUB 菜单并创建虚拟机 |
| `adapt_tencentos.sh` | 虚拟机内 | 将 TencentOS 3.1 适配为 EL8 兼容标识 |

创建类脚本支持的主要参数：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `-VMPath` | `VMs` | 虚拟机文件存放目录 |
| `-SwitchName` | `PigstyExternal` | 外部虚拟交换机名称 |
| `-CPUCount` | `4` | 每台虚拟机的 CPU 核数 |
| `-MemoryGB` | `8` | 每台虚拟机的内存大小（GB） |
| `-DiskGB` | `100` | 每台虚拟机的磁盘大小（GB） |
| `-ISOPath` | `TencentOS-Server-3.1-...-minimal.iso` | TencentOS 安装镜像路径 |
| `-KSPath` | `ks` | Kickstart 文件输出目录 |
| `-RootPassword` | `Pigsty@2024` | root 与 admin 用户密码 |

## 目录结构

```text
pigsty4txos/
├── ks/                          # 各节点 Kickstart 配置（node1/2/3）
├── ks.cfg                       # 通用 Kickstart 模板
├── adapt_tencentos.sh           # TencentOS 3.1 EL8 适配脚本
├── create_pigsty_vms.ps1        # 虚拟机创建脚本（手动安装）
├── create_vms.ps1               # 虚拟机创建脚本（DHCP + Kickstart）
├── create_pigsty_vms_auto.ps1   # 虚拟机创建脚本（静态 IP + Kickstart）
├── setup_auto_install.ps1       # 自定义 ISO 一键准备脚本
├── quick_fix_hyperv.ps1         # Hyper-V 快速修复
├── diagnose_hyperv.ps1          # Hyper-V 诊断（中文）
├── diagnose_hyperv_en.ps1       # Hyper-V 诊断（英文）
├── get                          # Pigsty 官方源码下载脚本
├── pigsty-421/                  # Pigsty v4.2.1 完整源码（playbooks 与 roles）
├── pigsty-v4.0.0-src/           # Pigsty v4.0.0 源码
└── pigsty-pkg-v4.0.0.el8/       # EL8 离线软件包相关文件
```

## 文档索引

| 文档 | 内容 |
|------|------|
| [hyper_v_setup_guide.md](./hyper_v_setup_guide.md) | Hyper-V 虚拟机创建完整步骤 |
| [hyperv_fix_guide.md](./hyperv_fix_guide.md) | 「虚拟机监控程序未运行」修复指南 |
| [auto_install_guide.md](./auto_install_guide.md) | Kickstart 自动安装的 4 种方式与参数速查 |
| [tencentos_adapt.md](./tencentos_adapt.md) | os-release 适配原理、手动步骤与常见问题 |
| [pigsty_el8_install.md](./pigsty_el8_install.md) | Pigsty 在 EL8 系统上的在线安装指南 |
| [pigsty_docs.md](./pigsty_docs.md) | Pigsty v4.2.1 官方文档整理 |

## 常见问题

### 虚拟机启动时报「虚拟机监控程序未运行」

依次执行 `.\quick_fix_hyperv.ps1` 和 `.\diagnose_hyperv.ps1` 排查；进入 BIOS/UEFI 开启 Intel VT-x（或 AMD-V）与 XD（或 NX），完全关机 10 秒后再开机，并关闭 WSL2、VMware、VirtualBox、Docker Desktop 等可能抢占虚拟化的软件。详细步骤见 [Hyper-V 修复指南](./hyperv_fix_guide.md)。

### Kickstart 没有自动生效

请逐项确认：宿主机上的 `python -m http.server 8080` 仍在运行；浏览器能访问 `http://localhost:8080/pigsty-node1.cfg`；GRUB 中填写的宿主机 IP 正确；宿主机防火墙已放行 8080 端口。

### 提示找不到 ISO 文件

脚本默认路径为 `\v4_txos`，需通过 `-ISOPath` 参数显式指定本机镜像位置。

### Pigsty 部署时仍识别不到操作系统

系统更新可能覆盖 `/etc/os-release`，在节点内重新执行 `sudo ./adapt_tencentos.sh`，确认 `ID=rocky`、`VERSION_ID=8.6` 后再部署。

## 相关链接

- [Pigsty 官方文档](https://pigsty.io/docs/)
- [Pigsty GitHub 仓库](https://github.com/pgsty/pigsty)
- [TencentOS 官方网站](https://tlinux.tencent.com/)
