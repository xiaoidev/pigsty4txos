# Pigsty v4 TencentOS 3.1 Setup

TencentOS 3.1 Hyper-V virtual machine setup scripts for Pigsty deployment.

## Files

- `create_vms.ps1` - Create Hyper-V VMs
- `adapt_tencentos.sh` - TencentOS adaptation script
- `ks/*.cfg` - Kickstart auto-install configs
- `quick_fix_hyperv.ps1` - Hyper-V diagnostics

## Usage

```powershell
# Create VMs
.\create_vms.ps1

# Fix Hyper-V issues
.\quick_fix_hyperv.ps1
```
