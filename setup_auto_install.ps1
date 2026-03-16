# 一键自动安装脚本
# 创建自定义 ISO 并自动安装 TencentOS

param(
    [string]$WorkPath = "d:\Models\pigsty\v4_txos",
    [string]$ISOPath = "d:\Models\pigsty\v4_txos\TencentOS-Server-3.1-20240925.0-TK4-x86_64-minimal.iso",
    [string]$VMPath = "D:\Hyper-V\VMs",
    [string]$SwitchName = "PigstyExternal",
    [string]$BaseIP = "192.168.1",
    [string]$RootPassword = "Pigsty@2024"
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $color = switch ($Level) {
        "INFO"  { "Green" }
        "WARN"  { "Yellow" }
        "ERROR" { "Red" }
        default { "White" }
    }
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [$Level] $Message" -ForegroundColor $color
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  TencentOS 3.1 一键自动安装脚本" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# 步骤 1: 创建 Kickstart 文件
Write-Log "步骤 1/5: 创建 Kickstart 配置文件..."

$ksPath = Join-Path $WorkPath "ks"
if (-not (Test-Path $ksPath)) {
    New-Item -Path $ksPath -ItemType Directory -Force | Out-Null
}

$nodes = @(
    @{ Name = "pigsty-node1"; IP = "$BaseIP.11" },
    @{ Name = "pigsty-node2"; IP = "$BaseIP.12" },
    @{ Name = "pigsty-node3"; IP = "$BaseIP.13" }
)

foreach ($node in $nodes) {
    $ksContent = @"
# TencentOS 3.1 Kickstart - $($node.Name)
install
text
keyboard --vckeymap=us --xlayouts='us'
lang en_US.UTF-8
timezone Asia/Shanghai --utc
network --bootproto=dhcp --device=link --hostname=$($node.Name) --activate
rootpw --plaintext $RootPassword
user --name=admin --password=$RootPassword --plaintext --gecos="Admin" --groups=wheel
services --enabled=sshd
firewall --disabled
selinux --permissive
bootloader --location=mbr
autopart --type=lvm
clearpart --all --initlabel

%packages --nobase
@core
openssh-server
openssh-clients
sudo
curl
wget
tar
python3
%end

%post --log=/root/ks-post.log
#!/bin/bash
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl restart sshd
cp /etc/os-release /etc/os-release.bak
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
echo "NODE_IP=$($node.IP)" >> /etc/pigsty.conf
%end
reboot
"@
    $ksFile = Join-Path $ksPath "$($node.Name).cfg"
    $ksContent | Out-File -FilePath $ksFile -Encoding ASCII -NoNewline
    Write-Log "  创建: $ksFile"
}

# 步骤 2: 解压 ISO
Write-Log "步骤 2/5: 解压 ISO 文件..."
$extractPath = Join-Path $WorkPath "iso_extract"
if (Test-Path $extractPath) {
    Remove-Item -Path $extractPath -Recurse -Force
}
New-Item -Path $extractPath -ItemType Directory -Force | Out-Null

& "C:\Program Files\7-Zip\7z.exe" x $ISOPath -o"$extractPath" -y | Out-Null
Write-Log "  解压完成: $extractPath"

# 步骤 3: 修改 GRUB 配置添加自动安装菜单
Write-Log "步骤 3/5: 修改启动配置..."

$grubCfgPath = Join-Path $extractPath "EFI\BOOT\grub.cfg"
if (-not (Test-Path $grubCfgPath)) {
    $grubCfgPath = Join-Path $extractPath "EFI\BOOT\BOOT.conf"
}

if (Test-Path $grubCfgPath) {
    $grubContent = Get-Content $grubCfgPath -Raw
    
    # 添加自动安装菜单项
    $autoMenu = @"

menuentry 'Install TencentOS 3.1 (Auto - Pigsty Node1)' --class fedora --class gnu-linux --class gnu --class os {
    linuxefi /images/pxeboot/vmlinuz inst.ks=hd:LABEL=TencentOS-Server-3.1:/ks/pigsty-node1.cfg quiet
    initrdefi /images/pxeboot/initrd.img
}
menuentry 'Install TencentOS 3.1 (Auto - Pigsty Node2)' --class fedora --class gnu-linux --class gnu --class os {
    linuxefi /images/pxeboot/vmlinuz inst.ks=hd:LABEL=TencentOS-Server-3.1:/ks/pigsty-node2.cfg quiet
    initrdefi /images/pxeboot/initrd.img
}
menuentry 'Install TencentOS 3.1 (Auto - Pigsty Node3)' --class fedora --class gnu-linux --class gnu --class os {
    linuxefi /images/pxeboot/vmlinuz inst.ks=hd:LABEL=TencentOS-Server-3.1:/ks/pigsty-node3.cfg quiet
    initrdefi /images/pxeboot/initrd.img
}
"@
    
    $grubContent + $autoMenu | Set-Content $grubCfgPath -NoNewline
    Write-Log "  修改完成: $grubCfgPath"
} else {
    Write-Log "  未找到 grub.cfg，跳过修改" "WARN"
}

# 复制 Kickstart 文件到 ISO
$ksDir = Join-Path $extractPath "ks"
New-Item -Path $ksDir -ItemType Directory -Force | Out-Null
Copy-Item -Path "$ksPath\*.cfg" -Destination $ksDir -Force
Write-Log "  复制 Kickstart 文件到 ISO"

# 步骤 4: 创建虚拟机
Write-Log "步骤 4/5: 创建虚拟机..."

# 检查虚拟交换机
$switch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
if (-not $switch) {
    Write-Log "虚拟交换机不存在，正在创建..." "WARN"
    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.InterfaceDescription -notlike "*Hyper-V*" } | Select-Object -First 1
    if ($adapter) {
        New-VMSwitch -Name $SwitchName -NetAdapterName $adapter.Name -AllowManagementOS $true | Out-Null
        Write-Log "  创建交换机: $SwitchName"
    } else {
        Write-Log "未找到可用网卡" "ERROR"
        exit 1
    }
}

# 创建虚拟机目录
if (-not (Test-Path $VMPath)) {
    New-Item -Path $VMPath -ItemType Directory -Force | Out-Null
}

foreach ($node in $nodes) {
    $existingVM = Get-VM -Name $node.Name -ErrorAction SilentlyContinue
    if ($existingVM) {
        Write-Log "  虚拟机已存在: $($node.Name)" "WARN"
        continue
    }
    
    $vmDir = Join-Path $VMPath $node.Name
    $vhdPath = Join-Path $vmDir "$($node.Name).vhdx"
    
    New-Item -Path $vmDir -ItemType Directory -Force | Out-Null
    New-VHD -Path $vhdPath -SizeBytes 100GB -Dynamic | Out-Null
    
    New-VM -Name $node.Name -Path $vmDir -MemoryStartupBytes 8GB `
        -BootDevice VHD -VHDPath $vhdPath -SwitchName $SwitchName -Generation 2 | Out-Null
    
    Set-VM -Name $node.Name -ProcessorCount 4
    Set-VMProcessor -VMName $node.Name -ExposeVirtualizationExtensions $true
    
    # 使用解压后的 ISO
    Add-VMDvdDrive -VMName $node.Name -Path $ISOPath
    
    $dvd = Get-VMDvdDrive -VMName $node.Name
    Set-VMFirmware -VMName $node.Name -FirstBootDevice $dvd
    
    Write-Log "  创建虚拟机: $($node.Name)"
}

# 步骤 5: 显示结果
Write-Log "步骤 5/5: 完成!"
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  安装准备完成!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "虚拟机列表:" -ForegroundColor Yellow
Get-VM -Name "pigsty-node*" | Format-Table Name, State, CPUCount, MemoryStartup -AutoSize
Write-Host ""
Write-Host "网络配置:" -ForegroundColor Yellow
foreach ($node in $nodes) {
    Write-Host "  $($node.Name): $($node.IP) (DHCP)"
}
Write-Host ""
Write-Host "root 密码: $RootPassword" -ForegroundColor Yellow
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  启动和安装步骤" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "方法 1: 使用 HTTP Kickstart (推荐)"
Write-Host "  1. 启动 HTTP 服务器:"
Write-Host "     cd $ksPath"
Write-Host "     python -m http.server 8080"
Write-Host ""
Write-Host "  2. 启动虚拟机:"
Write-Host "     Start-VM -Name 'pigsty-node1'"
Write-Host "     vmconnect localhost pigsty-node1"
Write-Host ""
Write-Host "  3. 在 GRUB 菜单按 'e' 编辑，添加:"
Write-Host "     inst.ks=http://YOUR_HOST_IP:8080/pigsty-node1.cfg"
Write-Host ""
Write-Host "方法 2: 手动安装"
Write-Host "  直接启动虚拟机，按提示完成安装"
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  快速启动命令" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Start-VM -Name 'pigsty-node1','pigsty-node2','pigsty-node3'"
Write-Host ""
