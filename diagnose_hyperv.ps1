# Hyper-V 诊断和修复脚本

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Hyper-V 诊断工具" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# 检查管理员权限
Write-Host "[1/5] 检查管理员权限..." -ForegroundColor Yellow
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-Host "  OK: 以管理员身份运行" -ForegroundColor Green
} else {
    Write-Host "  ERROR: 请以管理员身份运行此脚本" -ForegroundColor Red
    Write-Host ""
    Write-Host "请右键点击 PowerShell，选择'以管理员身份运行'" -ForegroundColor Yellow
    exit 1
}

# 检查 Hyper-V 功能状态
Write-Host ""
Write-Host "[2/5] 检查 Hyper-V 功能..." -ForegroundColor Yellow
$hypervAll = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
$hypervPlatform = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V
$hypervManagementTools = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Tools-All

Write-Host "  Hyper-V All: $($hypervAll.State)"
Write-Host "  Hyper-V Platform: $($hypervPlatform.State)"
Write-Host "  Hyper-V Tools: $($hypervManagementTools.State)"

if ($hypervAll.State -ne "Enabled") {
    Write-Host "  启用 Hyper-V 功能中..." -ForegroundColor Yellow
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All -NoRestart
    Write-Host "  Hyper-V 功能已启用，需要重启" -ForegroundColor Green
} else {
    Write-Host "  Hyper-V 功能正常" -ForegroundColor Green
}

# 检查 Hyper-V 服务
Write-Host ""
Write-Host "[3/5] 检查 Hyper-V 服务..." -ForegroundColor Yellow
$services = @("vmms", "vmic", "vmbus", "vmcompute")
foreach ($svc in $services) {
    $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($service) {
        Write-Host "  $svc : $($service.Status)"
        if ($service.Status -ne "Running") {
            Write-Host "    启动服务中..."
            Start-Service -Name $svc
        }
    }
}

# 检查虚拟化状态
Write-Host ""
Write-Host "[4/5] 检查硬件虚拟化..." -ForegroundColor Yellow
try {
    $computerInfo = Get-ComputerInfo
    Write-Host "  HyperVisorPresent: $($computerInfo.HyperVisorPresent)"
    if (-not $computerInfo.HyperVisorPresent) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Red
        Write-Host "  虚拟化监控程序未运行!" -ForegroundColor Red
        Write-Host "============================================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "请检查以下项目:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "1. BIOS 中启用:"
        Write-Host "   - Intel VT-x / AMD-V"
        Write-Host "   - Intel VT-d / AMD IOMMU (可选)"
        Write-Host "   - Hardware DEP (数据执行保护)"
        Write-Host ""
        Write-Host "2. 关闭电脑并重新启动 (不仅仅是重启)"
        Write-Host ""
        Write-Host "3. 禁用其他虚拟化软件:"
        Write-Host "   - VMware Workstation"
        Write-Host "   - VirtualBox"
        Write-Host "   - WSL2 (Windows Subsystem for Linux)"
        Write-Host "   - Sandbox"
        Write-Host ""
        Write-Host "4. 禁用安全启动 (可选，如果 BIOS 有此选项)"
        Write-Host ""
    } else {
        Write-Host "  虚拟化监控程序正常" -ForegroundColor Green
    }
} catch {
    Write-Host "  无法获取计算机信息" -ForegroundColor Red
}

# 检查引导配置
Write-Host ""
Write-Host "[5/5] 检查引导配置..." -ForegroundColor Yellow
try {
    bcdedit /enum
    $hypervisorLaunch = bcdedit /enum | Select-String "hypervisorlaunchtype"
    if ($hypervisorLaunch) {
        Write-Host "  $hypervisorLaunch"
        if (-not ($hypervisorLaunch -match "auto")) {
            Write-Host "  设置 hypervisorlaunchtype 为 auto..."
            bcdedit /set {current} hypervisorlaunchtype auto
            Write-Host "  已设置，需要重启" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "  无法检查引导配置" -ForegroundColor Red
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  诊断完成" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "如果已进行了 BIOS 或引导配置更改，请:" -ForegroundColor Yellow
Write-Host "1. 完全关闭电脑电源"
Write-Host "2. 等待 10 秒"
Write-Host "3. 重新开机"
Write-Host ""
Write-Host "然后重新运行此脚本验证"
