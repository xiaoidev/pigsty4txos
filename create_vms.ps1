param(
    [string]$VMPath = "D:\Hyper-V\VMs",
    [string]$SwitchName = "PigstyExternal",
    [int]$CPUCount = 4,
    [int]$MemoryGB = 8,
    [int]$DiskGB = 100,
    [string]$ISOPath = "d:\Models\pigsty\v4_txos\TencentOS-Server-3.1-20240925.0-TK4-x86_64-minimal.iso",
    [string]$KSPath = "d:\Models\pigsty\v4_txos\ks",
    [string]$BaseIP = "192.168.1",
    [string]$Gateway = "192.168.1.1",
    [string]$DNS = "8.8.8.8",
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

$nodes = @(
    @{ Name = "pigsty-node1"; IP = "$BaseIP.11"; Role = "meta" },
    @{ Name = "pigsty-node2"; IP = "$BaseIP.12"; Role = "replica" },
    @{ Name = "pigsty-node3"; IP = "$BaseIP.13"; Role = "replica" }
)

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  TencentOS 3.1 Pigsty VM Creator" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "Step 1: Creating Kickstart files..."

if (-not (Test-Path $KSPath)) {
    New-Item -Path $KSPath -ItemType Directory -Force | Out-Null
}

foreach ($node in $nodes) {
    $nodeIP = $node.IP
    $nodeName = $node.Name
    $nodeRole = $node.Role
    
    $ksContent = "# TencentOS 3.1 Kickstart - $nodeName`n"
    $ksContent += "install`n"
    $ksContent += "text`n"
    $ksContent += "keyboard --vckeymap=us --xlayouts='us'`n"
    $ksContent += "lang en_US.UTF-8`n"
    $ksContent += "timezone Asia/Shanghai --utc`n"
    $ksContent += "network --bootproto=dhcp --device=link --hostname=$nodeName --activate`n"
    $ksContent += "rootpw --plaintext $RootPassword`n"
    $ksContent += "user --name=admin --password=$RootPassword --plaintext --gecos=Admin --groups=wheel`n"
    $ksContent += "services --enabled=sshd`n"
    $ksContent += "firewall --disabled`n"
    $ksContent += "selinux --permissive`n"
    $ksContent += "bootloader --location=mbr`n"
    $ksContent += "autopart --type=lvm`n"
    $ksContent += "clearpart --all --initlabel`n"
    $ksContent += "`n"
    $ksContent += "%packages --nobase`n"
    $ksContent += "@core`n"
    $ksContent += "openssh-server`n"
    $ksContent += "openssh-clients`n"
    $ksContent += "sudo`n"
    $ksContent += "curl`n"
    $ksContent += "wget`n"
    $ksContent += "tar`n"
    $ksContent += "python3`n"
    $ksContent += "%end`n"
    $ksContent += "`n"
    $ksContent += "%post --log=/root/ks-post.log`n"
    $ksContent += "#!/bin/bash`n"
    $ksContent += "echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel`n"
    $ksContent += "sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config`n"
    $ksContent += "sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config`n"
    $ksContent += "systemctl restart sshd`n"
    $ksContent += "cp /etc/os-release /etc/os-release.bak`n"
    $ksContent += "cat > /etc/os-release << 'OSEOF'`n"
    $ksContent += 'NAME="TencentOS Server"' + "`n"
    $ksContent += 'VERSION="3.1 (EL8 Compatible)"' + "`n"
    $ksContent += 'ID="rocky"' + "`n"
    $ksContent += 'ID_LIKE="rhel centos fedora tencentos"' + "`n"
    $ksContent += 'VERSION_ID="8.6"' + "`n"
    $ksContent += 'PLATFORM_ID="platform:el8"' + "`n"
    $ksContent += 'PRETTY_NAME="TencentOS Server 3.1 (EL8 Compatible)"' + "`n"
    $ksContent += 'ANSI_COLOR="0;31"' + "`n"
    $ksContent += 'CPE_NAME="cpe:/o/rocky:rocky:8"' + "`n"
    $ksContent += 'HOME_URL="https://tlinux.tencent.com/"' + "`n"
    $ksContent += 'BUG_REPORT_URL="https://tlinux.tencent.com/"' + "`n"
    $ksContent += 'ROCKY_SUPPORT_PRODUCT="Rocky Linux"' + "`n"
    $ksContent += 'ROCKY_SUPPORT_PRODUCT_VERSION="8"' + "`n"
    $ksContent += "OSEOF`n"
    $ksContent += "echo 'NODE_NAME=$nodeName' >> /etc/pigsty.conf`n"
    $ksContent += "echo 'NODE_IP=$nodeIP' >> /etc/pigsty.conf`n"
    $ksContent += "echo 'NODE_ROLE=$nodeRole' >> /etc/pigsty.conf`n"
    $ksContent += "echo 'Kickstart completed for $nodeName' >> /root/ks-post.log`n"
    $ksContent += "%end`n"
    $ksContent += "`n"
    $ksContent += "reboot`n"
    
    $ksFile = Join-Path $KSPath "$nodeName.cfg"
    [System.IO.File]::WriteAllText($ksFile, $ksContent, [System.Text.Encoding]::ASCII)
    Write-Log "  Created: $ksFile"
}

Write-Log "Step 2: Checking prerequisites..."

if (-not (Test-Path $ISOPath)) {
    Write-Log "ISO not found: $ISOPath" "ERROR"
    exit 1
}
Write-Log "  ISO: OK"

if (-not (Test-Path $VMPath)) {
    New-Item -Path $VMPath -ItemType Directory -Force | Out-Null
}

$switch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
if (-not $switch) {
    Write-Log "Switch not found: $SwitchName" "WARN"
    Write-Log "  Creating external switch..."
    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.InterfaceDescription -notlike "*Hyper-V*" } | Select-Object -First 1
    if ($adapter) {
        New-VMSwitch -Name $SwitchName -NetAdapterName $adapter.Name -AllowManagementOS $true | Out-Null
        Write-Log "  Created switch: $SwitchName"
    } else {
        Write-Log "No available network adapter" "ERROR"
        exit 1
    }
} else {
    Write-Log "  Switch: OK"
}

Write-Log "Step 3: Creating virtual machines..."

$memoryBytes = $MemoryGB * 1GB
$diskBytes = $DiskGB * 1GB

foreach ($node in $nodes) {
    $vmName = $node.Name
    $existingVM = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    
    if ($existingVM) {
        Write-Log "  VM exists: $vmName" "WARN"
        continue
    }
    
    Write-Log "  Creating: $vmName"
    
    $vmDir = Join-Path $VMPath $vmName
    $vhdPath = Join-Path $vmDir "$vmName.vhdx"
    
    New-Item -Path $vmDir -ItemType Directory -Force | Out-Null
    New-VHD -Path $vhdPath -SizeBytes $diskBytes -Dynamic | Out-Null
    
    New-VM -Name $vmName -Path $vmDir -MemoryStartupBytes $memoryBytes `
        -BootDevice VHD -VHDPath $vhdPath -SwitchName $SwitchName -Generation 2 | Out-Null
    
    Set-VM -Name $vmName -ProcessorCount $CPUCount
    Set-VMProcessor -VMName $vmName -ExposeVirtualizationExtensions $true
    
    Add-VMDvdDrive -VMName $vmName -Path $ISOPath
    $dvd = Get-VMDvdDrive -VMName $vmName
    Set-VMFirmware -VMName $vmName -FirstBootDevice $dvd
    
    Write-Log "    Done: $vmName"
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  VM Creation Complete!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

Get-VM -Name "pigsty-node*" | Format-Table Name, State, CPUCount, MemoryStartup -AutoSize

Write-Host ""
Write-Host "Network: $SwitchName"
Write-Host "Root Password: $RootPassword"
Write-Host "Kickstart Files: $KSPath"
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Next Steps" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Start HTTP server for Kickstart:"
Write-Host "   cd $KSPath"
Write-Host "   python -m http.server 8080"
Write-Host ""
Write-Host "2. Start VMs:"
Write-Host "   Start-VM -Name 'pigsty-node1','pigsty-node2','pigsty-node3'"
Write-Host ""
Write-Host "3. In GRUB menu, press 'e' and add:"
Write-Host "   inst.ks=http://HOST_IP:8080/pigsty-node1.cfg"
Write-Host ""
