# Hyper-V 虚拟机监控程序修复指南

## 问题描述
虚拟机无法启动，错误："虚拟机监控程序未运行"

---

## 解决方案

### 第一步：运行诊断脚本

**以管理员身份**运行 PowerShell，执行：

```powershell
cd d:\Models\pigsty\v4_txos
.\diagnose_hyperv.ps1
```

---

### 第二步：检查 BIOS/UEFI 设置

重启电脑，进入 BIOS/UEFI，启用以下选项：

| 选项 | Intel | AMD |
|------|-------|-----|
| 硬件虚拟化 | Intel VT-x | AMD-V / SVM |
| I/O 虚拟化 (可选) | Intel VT-d | AMD IOMMU |
| 数据执行保护 | Execute Disable (XD) | No Execute (NX) |

**重要**: 启用后必须**完全关闭电源**，等待 10 秒再开机，不要只重启！

---

### 第三步：禁用其他虚拟化软件

冲突的软件需要临时禁用或卸载：

- VMware Workstation / Player
- VirtualBox
- WSL2 (Windows Subsystem for Linux)
- Windows Sandbox
- Docker Desktop

#### 禁用 WSL2:
```powershell
wsl --shutdown
```

#### 禁用 Windows Sandbox:
```powershell
Disable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM
```

---

### 第四步：配置 Hyper-V 自动启动

在**管理员 PowerShell** 中执行：

```powershell
# 设置 Hyper-V 自动启动
bcdedit /set {current} hypervisorlaunchtype auto

# 验证
bcdedit /enum | findstr "hypervisorlaunchtype"
```

---

### 第五步：重启并验证

```powershell
# 重启电脑
Restart-Computer
```

重启后验证：

```powershell
# 检查监控程序状态
Get-ComputerInfo | Select-Object HyperVisorPresent

# 应该显示: HyperVisorPresent : True

# 尝试启动虚拟机
Start-VM -Name "pigsty-node1"
```

---

## 快速检查清单

- [ ] 以管理员身份运行 PowerShell
- [ ] BIOS 中启用了 VT-x/VT-d 或 AMD-V/IOMMU
- [ ] 完全关闭电源并重新开机
- [ ] 禁用了 WSL2、VMware、VirtualBox 等
- [ ] 运行 `bcdedit /set {current} hypervisorlaunchtype auto`
- [ ] 重启后 `HyperVisorPresent` 显示为 `True`

---

## 替代方案：使用 VirtualBox 或 VMware

如果 Hyper-V 问题无法解决，可以使用其他虚拟机软件：

### VirtualBox
```powershell
# 下载 VirtualBox
# https://www.virtualbox.org/
```

### VMware Workstation Player
```powershell
# 下载 VMware Workstation Player
# https://www.vmware.com/products/workstation-player.html
```

---

## 文件清单

| 文件 | 说明 |
|------|------|
| `diagnose_hyperv.ps1` | Hyper-V 诊断脚本 |
| `create_vms.ps1` | 虚拟机创建脚本 |
| `ks/*.cfg` | Kickstart 自动安装配置 |
