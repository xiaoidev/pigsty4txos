# Quick Hyper-V Fix Script
# Simple steps to fix hypervisor issues

Write-Host ""
Write-Host "Hyper-V Quick Fix" -ForegroundColor Cyan
Write-Host ""

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: Run as Administrator!" -ForegroundColor Red
    exit 1
}

# Step 1: Enable Hyper-V features
Write-Host "Step 1: Enabling Hyper-V features..." -ForegroundColor Yellow
$hyperv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
if ($hyperv.State -ne "Enabled") {
    Write-Host "  Enabling..."
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All -NoRestart
} else {
    Write-Host "  Already enabled" -ForegroundColor Green
}

# Step 2: Set hypervisor to auto start
Write-Host ""
Write-Host "Step 2: Setting hypervisor to auto start..." -ForegroundColor Yellow
bcdedit /set {current} hypervisorlaunchtype auto
Write-Host "  Done" -ForegroundColor Green

# Step 3: Show status
Write-Host ""
Write-Host "Step 3: Checking hypervisor status..." -ForegroundColor Yellow
try {
    $info = Get-ComputerInfo
    Write-Host "  HyperVisorPresent: $($info.HyperVisorPresent)"
    if ($info.HyperVisorPresent) {
        Write-Host ""
        Write-Host "SUCCESS: Hypervisor is running!" -ForegroundColor Green
        Write-Host "You can try starting VMs now."
        Write-Host "  Start-VM -Name 'pigsty-node1'"
    } else {
        Write-Host ""
        Write-Host "REQUIRES REBOOT & BIOS CHECK" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please do the following:"
        Write-Host "1. Reboot your computer"
        Write-Host "2. Enter BIOS/UEFI"
        Write-Host "3. Enable Intel VT-x / AMD-V"
        Write-Host "4. Enable Hardware DEP"
        Write-Host "5. FULLY POWER OFF, wait 10s, then power ON"
        Write-Host "6. Disable WSL2, VMware, VirtualBox if needed"
        Write-Host ""
        Write-Host "After BIOS changes, run this script again."
    }
} catch {
    Write-Host "  Cannot check status" -ForegroundColor Red
}

Write-Host ""
