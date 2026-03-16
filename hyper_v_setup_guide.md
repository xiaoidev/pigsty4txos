# TencentOS 3.1 Hyper-V 虚拟机创建指南

## 概述

使用 TencentOS-Server-3.1-20240925.0-TK4-x86_64-minimal.iso 创建 3 台虚拟机用于 Pigsty 集群部署。

---

## 前置条件

1. **Hyper-V 已启用** (Windows 10/11 Pro/Enterprise 或 Windows Server)
2. **管理员权限**
3. **ISO 文件**: `d:\Models\pigsty\v4_txos\TencentOS-Server-3.1-20240925.0-TK4-x86_64-minimal.iso`

---

## 步骤 1: 启用 Hyper-V (如未启用)

以**管理员身份**打开 PowerShell，执行：

```powershell
# 检查 Hyper-V 状态
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All

# 如果未启用，执行以下命令并重启
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
```

---

## 步骤 2: 创建外部虚拟交换机

```powershell
# 查看可用网卡
Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object Name, InterfaceDescription

# 创建外部交换机 (替换 "以太网" 为你的网卡名称)
$adapterName = "以太网"  # 或 "Ethernet"、"WLAN" 等
New-VMSwitch -Name "PigstyExternal" -NetAdapterName $adapterName -AllowManagementOS $true

# 验证交换机
Get-VMSwitch -Name "PigstyExternal"
```

---

## 步骤 3: 创建虚拟机

### 配置参数

| 参数 | 值 |
|------|-----|
| 虚拟机名称 | pigsty-node1, pigsty-node2, pigsty-node3 |
| CPU | 4 核 |
| 内存 | 8 GB |
| 磁盘 | 100 GB |
| 网络 | PigstyExternal (外部交换机) |
| ISO | TencentOS-Server-3.1-20240925.0-TK4-x86_64-minimal.iso |

### 创建脚本

```powershell
# 配置变量
$VMPath = "D:\Hyper-V\VMs"
$SwitchName = "PigstyExternal"
$ISOPath = "d:\Models\pigsty\v4_txos\TencentOS-Server-3.1-20240925.0-TK4-x86_64-minimal.iso"
$CPUCount = 4
$MemoryGB = 8
$DiskGB = 100

# 创建虚拟机目录
New-Item -Path $VMPath -ItemType Directory -Force

# 创建 3 台虚拟机
1..3 | ForEach-Object {
    $VMName = "pigsty-node$_"
    $vmDir = Join-Path $VMPath $VMName
    $vhdPath = Join-Path $vmDir "$VMName.vhdx"
    
    Write-Host "创建虚拟机: $VMName" -ForegroundColor Green
    
    # 创建目录
    New-Item -Path $vmDir -ItemType Directory -Force
    
    # 创建虚拟硬盘
    New-VHD -Path $vhdPath -SizeBytes ($DiskGB * 1GB) -Dynamic
    
    # 创建虚拟机 (Generation 2)
    New-VM -Name $VMName -Path $vmDir -MemoryStartupBytes ($MemoryGB * 1GB) `
        -BootDevice VHD -VHDPath $vhdPath -SwitchName $SwitchName -Generation 2
    
    # 配置 CPU
    Set-VM -Name $VMName -ProcessorCount $CPUCount
    
    # 挂载 ISO
    Add-VMDvdDrive -VMName $VMName -Path $ISOPath
    
    # 设置启动顺序 (DVD 优先)
    $dvd = Get-VMDvdDrive -VMName $VMName
    Set-VMFirmware -VMName $VMName -FirstBootDevice $dvd
    
    # 启用嵌套虚拟化 (可选)
    Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true
    
    Write-Host "  完成: $VMName" -ForegroundColor Cyan
}

# 显示创建结果
Get-VM -Name "pigsty-node*" | Format-Table Name, State, CPUCount, MemoryStartup -AutoSize
```

---

## 步骤 4: 启动虚拟机

```powershell
# 启动所有虚拟机
Start-VM -Name "pigsty-node1"
Start-VM -Name "pigsty-node2"
Start-VM -Name "pigsty-node3"

# 或一次性启动
Get-VM -Name "pigsty-node*" | Start-VM

# 连接到虚拟机控制台
vmconnect.exe localhost pigsty-node1
```

---

## 步骤 5: 安装 TencentOS

1. 连接到虚拟机控制台
2. 选择 "Install TencentOS Server 3.1"
3. 配置分区 (建议使用 LVM)
4. 设置 root 密码
5. 完成安装后重启

### 推荐分区方案

| 挂载点 | 大小 | 说明 |
|--------|------|------|
| /boot | 1 GB | 引导分区 |
| /boot/efi | 512 MB | EFI 分区 |
| swap | 8 GB | 交换分区 |
| / | 剩余空间 | 根分区 |

---

## 步骤 6: 配置网络

安装完成后，为每台虚拟机配置静态 IP：

```bash
# 在 TencentOS 虚拟机中执行
nmcli con show  # 查看网络连接

# 配置静态 IP (示例)
nmcli con modify ens33 \
    ipv4.addresses 192.168.1.11/24 \
    ipv4.gateway 192.168.1.1 \
    ipv4.dns "8.8.8.8,114.114.114.114" \
    ipv4.method manual

nmcli con up ens33
```

### 推荐网络规划

| 虚拟机 | IP 地址 | 角色 |
|--------|---------|------|
| pigsty-node1 | 192.168.1.11 | Meta / Primary |
| pigsty-node2 | 192.168.1.12 | Replica |
| pigsty-node3 | 192.168.1.13 | Replica |

---

## 步骤 7: 执行 TencentOS 适配

在每台虚拟机上执行适配脚本：

```bash
# 上传适配脚本
scp adapt_tencentos.sh root@192.168.1.11:/tmp/

# 执行适配
chmod +x /tmp/adapt_tencentos.sh
sudo /tmp/adapt_tencentos.sh
```

---

## 步骤 8: 部署 Pigsty

```bash
# 上传离线包到 node1
scp pigsty-pkg-v4.0.0.el8.x86_64.tgz root@192.168.1.11:/tmp/pkg.tgz

# 在 node1 上执行
curl -fsSL https://repo.pigsty.io/get | bash -s v4.0.0
cd ~/pigsty
./bootstrap -p /tmp/pkg.tgz
./configure -g
./deploy.yml
```

---

## 常用命令

```powershell
# 查看所有虚拟机
Get-VM

# 启动/停止虚拟机
Start-VM -Name "pigsty-node1"
Stop-VM -Name "pigsty-node1"

# 连接到虚拟机
vmconnect.exe localhost pigsty-node1

# 删除虚拟机
Remove-VM -Name "pigsty-node1" -Force
Remove-Item -Path "D:\Hyper-V\VMs\pigsty-node1" -Recurse -Force

# 查看虚拟机详情
Get-VM -Name "pigsty-node1" | Format-List *
```

---

## 文件清单

| 文件 | 说明 |
|------|------|
| `create_pigsty_vms.ps1` | PowerShell 自动创建脚本 |
| `adapt_tencentos.sh` | TencentOS 适配脚本 |
| `tencentos_adapt.md` | 适配文档 |
| `TencentOS-Server-3.1-20240925.0-TK4-x86_64-minimal.iso` | ISO 镜像 |
| `pigsty-pkg-v4.0.0.el8.x86_64.tgz` | Pigsty EL8 离线包 |
