# Hyper-V Diagnostics Script
# English version to avoid encoding issues

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Hyper-V Diagnostics Tool" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check admin privileges
Write-Host "[1/5] Checking administrator privileges..." -ForegroundColor Yellow
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-Host "  OK: Running as administrator" -ForegroundColor Green
} else {
    Write-Host "  ERROR: Please run this script as Administrator" -ForegroundColor Red
    Write-Host ""
    Write-Host "Right-click PowerShell and select 'Run as administrator'" -ForegroundColor Yellow
    exit 1
}

# Step 2: Check Hyper-V feature state
Write-Host ""
Write-Host "[2/5] Checking Hyper-V features..." -ForegroundColor Yellow
$hypervAll = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
$hypervPlatform = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V
$hypervManagementTools = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Tools-All

Write-Host "  Hyper-V All: $($hypervAll.State)"
Write-Host "  Hyper-V Platform: $($hypervPlatform.State)"
Write-Host "  Hyper-V Tools: $($hypervManagementTools.State)"

if ($hypervAll.State -ne "Enabled") {
    Write-Host "  Enabling Hyper-V features..." -ForegroundColor Yellow
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All -NoRestart
    Write-Host "  Hyper-V enabled, please reboot" -ForegroundColor Green
} else {
    Write-Host "  Hyper-V features OK" -ForegroundColor Green
}

# Step 3: Check Hyper-V services
Write-Host ""
Write-Host "[3/5] Checking Hyper-V services..." -ForegroundColor Yellow
$services = @("vmms", "vmcompute")
foreach ($svc in $services) {
    $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($service) {
        Write-Host "  $svc : $($service.Status)"
        if ($service.Status -ne "Running") {
            Write-Host "    Starting service..."
            Start-Service -Name $svc
        }
    }
}

# Step 4: Check hardware virtualization
Write-Host ""
Write-Host "[4/5] Checking hardware virtualization..." -ForegroundColor Yellow
try {
    $computerInfo = Get-ComputerInfo
    Write-Host "  HyperVisorPresent: $($computerInfo.HyperVisorPresent)"
    if (-not $computerInfo.HyperVisorPresent) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Red
        Write-Host "  Hypervisor is NOT running!" -ForegroundColor Red
        Write-Host "============================================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please check the following:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "1. Enable in BIOS/UEFI:"
        Write-Host "   - Intel VT-x / AMD-V"
        Write-Host "   - Intel VT-d / AMD IOMMU (optional)"
        Write-Host "   - Hardware DEP (Data Execution Prevention)"
        Write-Host ""
        Write-Host "2. Fully power off your computer and restart (not just reboot)"
        Write-Host ""
        Write-Host "3. Disable other virtualization software:"
        Write-Host "   - VMware Workstation"
        Write-Host "   - VirtualBox"
        Write-Host "   - WSL2 (Windows Subsystem for Linux)"
        Write-Host "   - Windows Sandbox"
        Write-Host ""
    } else {
        Write-Host "  Hypervisor is OK" -ForegroundColor Green
    }
} catch {
    Write-Host "  Cannot get computer info" -ForegroundColor Red
}

# Step 5: Check boot configuration
Write-Host ""
Write-Host "[5/5] Checking boot configuration..." -ForegroundColor Yellow
try {
    $hypervisorLaunch = bcdedit /enum | Select-String "hypervisorlaunchtype"
    if ($hypervisorLaunch) {
        Write-Host "  $hypervisorLaunch"
        if (-not ($hypervisorLaunch -match "auto")) {
            Write-Host "  Setting hypervisorlaunchtype to auto..."
            bcdedit /set {current} hypervisorlaunchtype auto
            Write-Host "  Set, please reboot" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "  Cannot check boot config" -ForegroundColor Red
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Diagnostics Complete" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "If you made BIOS or boot config changes:" -ForegroundColor Yellow
Write-Host "1. Fully power off your computer"
Write-Host "2. Wait 10 seconds"
Write-Host "3. Power back on"
Write-Host ""
Write-Host "Then run this script again to verify"
