# TencentOS 3.1 Hyper-V 虚拟机创建脚本
# 用于 Pigsty v4.0.0 集群部署

param(
    [string]$VMPath = "D:\Hyper-V\VMs",
    [string]$SwitchName = "PigstyExternal",
    [int]$CPUCount = 4,
    [int]$MemoryGB = 8,
    [int]$DiskGB = 100,
    [string]$ISOPath = "d:\Models\pigsty\v4_txos\TencentOS-Server-3.1-20240925.0-TK4-x86_64-minimal.iso"
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

# 1. 检查 Hyper-V
Write-Log "检查 Hyper-V 环境..."
$hyperv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
if (-not $hyperv -or $hyperv.State -ne "Enabled") {
    Write-Log "Hyper-V 未安装或未启用" "ERROR"
    Write-Log "请先启用 Hyper-V: Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All"
    exit 1
}

# 2. 检查 ISO 文件
if (-not (Test-Path $ISOPath)) {
    Write-Log "ISO 文件不存在: $ISOPath" "ERROR"
    exit 1
}
Write-Log "ISO 文件: $ISOPath"

# 3. 创建虚拟机目录
if (-not (Test-Path $VMPath)) {
    New-Item -Path $VMPath -ItemType Directory -Force | Out-Null
    Write-Log "创建目录: $VMPath"
}

# 4. 查找物理网卡并创建外部交换机
Write-Log "查找物理网卡..."
$physicalAdapter = Get-NetAdapter | Where-Object { 
    $_.Status -eq "Up" -and 
    $_.InterfaceDescription -notlike "*Hyper-V*" -and
    $_.InterfaceDescription -notlike "*Virtual*" -and
    $_.InterfaceDescription -notlike "*Bluetooth*"
} | Select-Object -First 1

if (-not $physicalAdapter) {
    Write-Log "未找到活动的物理网卡" "ERROR"
    Write-Log "可用网卡列表:"
    Get-NetAdapter | Format-Table Name, InterfaceDescription, Status
    exit 1
}

Write-Log "选择网卡: $($physicalAdapter.Name) [$($physicalAdapter.InterfaceDescription)]"

# 检查交换机是否已存在
$existingSwitch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
if ($existingSwitch) {
    Write-Log "虚拟交换机已存在: $SwitchName" "WARN"
} else {
    Write-Log "创建外部虚拟交换机: $SwitchName"
    New-VMSwitch -Name $SwitchName -NetAdapterName $physicalAdapter.Name -AllowManagementOS $true | Out-Null
    Write-Log "虚拟交换机创建成功" "INFO"
}

# 5. 创建虚拟机函数
function New-PigstyVM {
    param(
        [string]$VMName,
        [string]$Path,
        [string]$SwitchName,
        [int]$CPUCount,
        [int64]$MemoryBytes,
        [int64]$DiskBytes,
        [string]$ISOPath
    )
    
    Write-Log "创建虚拟机: $VMName"
    
    $vmPath = Join-Path $Path $VMName
    $vhdPath = Join-Path $vmPath "$VMName.vhdx"
    
    # 创建虚拟机目录
    New-Item -Path $vmPath -ItemType Directory -Force | Out-Null
    
    # 创建虚拟硬盘
    Write-Log "  创建虚拟硬盘: $vhdPath ($([math]::Round($DiskBytes/1GB, 0)) GB)"
    New-VHD -Path $vhdPath -SizeBytes $DiskBytes -Dynamic | Out-Null
    
    # 创建虚拟机
    Write-Log "  创建虚拟机 (CPU: $CPUCount, 内存: $([math]::Round($MemoryBytes/1GB, 0)) GB)"
    $vm = New-VM -Name $VMName -Path $vmPath -MemoryStartupBytes $MemoryBytes `
        -BootDevice VHD -VHDPath $vhdPath -SwitchName $SwitchName `
        -Generation 2
    
    # 配置虚拟机
    Set-VM -Name $VMName -ProcessorCount $CPUCount -AutomaticStartAction StartIfRunning -AutomaticStopAction ShutDown
    
    # 挂载 ISO
    Add-VMDvdDrive -VMName $VMName -Path $ISOPath
    
    # 设置启动顺序 (硬盘优先)
    $dvd = Get-VMDvdDrive -VMName $VMName
    Set-VMFirmware -VMName $VMName -FirstBootDevice $dvd
    
    # 启用嵌套虚拟化 (可选)
    Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true
    
    Write-Log "  虚拟机创建完成: $VMName" "INFO"
    
    return $vm
}

# 6. 创建 3 台虚拟机
$memoryBytes = $MemoryGB * 1GB
$diskBytes = $DiskGB * 1GB

$vmNames = @("pigsty-node1", "pigsty-node2", "pigsty-node3")

foreach ($vmName in $vmNames) {
    # 检查是否已存在
    $existingVM = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    if ($existingVM) {
        Write-Log "虚拟机已存在: $vmName" "WARN"
        continue
    }
    
    New-PigstyVM -VMName $vmName -Path $VMPath -SwitchName $SwitchName `
        -CPUCount $CPUCount -MemoryBytes $memoryBytes -DiskBytes $diskBytes -ISOPath $ISOPath
}

# 7. 显示创建结果
Write-Log "`n============================================"
Write-Log "虚拟机创建完成!"
Write-Log "============================================"
Write-Log ""
Write-Log "虚拟机列表:"
Get-VM -Name "pigsty-node*" | Format-Table Name, State, CPUCount, MemoryStartup, Uptime -AutoSize

Write-Log ""
Write-Log "网络配置:"
Write-Log "  虚拟交换机: $SwitchName (External)"
Write-Log "  绑定网卡: $($physicalAdapter.Name)"
Write-Log ""
Write-Log "后续步骤:"
Write-Log "  1. 启动虚拟机: Start-VM -Name 'pigsty-node*'"
Write-Log "  2. 连接到虚拟机控制台进行系统安装"
Write-Log "  3. 安装完成后配置 IP 地址"
Write-Log "  4. 执行 TencentOS 适配脚本"
Write-Log "  5. 部署 Pigsty 集群"
Write-Log ""
Write-Log "快速启动所有虚拟机:"
Write-Log "  Start-VM -Name 'pigsty-node1','pigsty-node2','pigsty-node3'"
