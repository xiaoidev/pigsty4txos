# TencentOS 3.1 自动安装完整指南

## 概述

本文档提供 TencentOS 3.1 虚拟机自动安装的多种方法。

---

## 方法 1: 使用 Kickstart + HTTP 服务器 (推荐)

### 步骤 1: 创建 Kickstart 文件

已生成以下文件：
- `ks\pigsty-node1.cfg` - 节点1 配置 (IP: 192.168.1.11)
- `ks\pigsty-node2.cfg` - 节点2 配置 (IP: 192.168.1.12)
- `ks\pigsty-node3.cfg` - 节点3 配置 (IP: 192.168.1.13)

### 步骤 2: 启动 HTTP 服务器

在宿主机上启动 HTTP 服务器提供 Kickstart 文件：

```powershell
# 进入 Kickstart 目录
cd d:\Models\pigsty\v4_txos\ks

# 启动 Python HTTP 服务器
python -m http.server 8080

# 或使用 PowerShell (如果安装了 PSWS)
# Start-PSWS -Port 8080 -Path .
```

### 步骤 3: 启动虚拟机并指定 Kickstart

```powershell
# 启动虚拟机
Start-VM -Name "pigsty-node1"

# 连接到虚拟机控制台
vmconnect.exe localhost pigsty-node1
```

### 步骤 4: 在 GRUB 菜单添加 Kickstart 参数

1. 在 GRUB 启动菜单出现时，按 **`e`** 键编辑启动项
2. 找到以 `linux` 或 `linuxefi` 开头的行
3. 在行末尾添加：
   ```
   inst.ks=http://192.168.1.1:8080/pigsty-node1.cfg
   ```
   (将 `192.168.1.1` 替换为宿主机的实际 IP)
4. 按 **`Ctrl+X`** 启动安装

### 步骤 5: 等待自动安装完成

安装过程约 5-10 分钟，完成后自动重启。

---

## 方法 2: 创建自定义 ISO (一次性设置)

### 步骤 1: 解压 ISO

```powershell
# 创建工作目录
mkdir d:\Models\pigsty\v4_txos\iso_extract
cd d:\Models\pigsty\v4_txos\iso_extract

# 使用 7-Zip 解压
& "C:\Program Files\7-Zip\7z.exe" x "d:\Models\pigsty\v4_txos\TencentOS-Server-3.1-20240925.0-TK4-x86_64-minimal.iso"
```

### 步骤 2: 修改启动配置

编辑 `EFI\BOOT\grub.cfg` 文件，添加自动安装菜单项：

```cfg
menuentry 'Install TencentOS 3.1 (Auto - Pigsty Node1)' --class fedora --class gnu-linux --class gnu --class os {
    linuxefi /images/pxeboot/vmlinuz inst.ks=http://192.168.1.1:8080/pigsty-node1.cfg quiet
    initrdefi /images/pxeboot/initrd.img
}

menuentry 'Install TencentOS 3.1 (Auto - Pigsty Node2)' --class fedora --class gnu-linux --class gnu --class os {
    linuxefi /images/pxeboot/vmlinuz inst.ks=http://192.168.1.1:8080/pigsty-node2.cfg quiet
    initrdefi /images/pxeboot/initrd.img
}

menuentry 'Install TencentOS 3.1 (Auto - Pigsty Node3)' --class fedora --class gnu-linux --class gnu --class os {
    linuxefi /images/pxeboot/vmlinuz inst.ks=http://192.168.1.1:8080/pigsty-node3.cfg quiet
    initrdefi /images/pxeboot/initrd.img
}
```

### 步骤 3: 重新打包 ISO

```powershell
# 使用 genisoimage 或 mkisofs (需要安装)
# 或使用 oscdimg (Windows ADK)

# 安装 Windows ADK 后:
oscdimg -m -o -u2 -udfver102 -bootdata:2#p0,e,bd:\Models\pigsty\v4_txos\iso_extract\images\efiboot.img#pEF,e,bd:\Models\pigsty\v4_txos\iso_extract\EFI\boot\bootx64.efi d:\Models\pigsty\v4_txos\iso_extract d:\Models\pigsty\v4_txos\TencentOS-3.1-Pigsty-Auto.iso
```

---

## 方法 3: 使用 PowerShell 自动化 (需要 Hyper-V Integration Services)

```powershell
# 创建自动安装脚本
$autoInstallScript = @'
# 等待虚拟机启动
Start-Sleep -Seconds 30

# 发送按键序列 (模拟键盘输入)
# 注意: 这需要虚拟机窗口处于活动状态

# 选择启动项 (假设第一个是安装)
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Start-Sleep -Seconds 5

# 在 GRUB 菜单按 'e' 编辑
[System.Windows.Forms.SendKeys]::SendWait("e")
Start-Sleep -Seconds 1

# 移动到 linux 行
[System.Windows.Forms.SendKeys]::SendWait("{DOWN}{DOWN}{DOWN}")
Start-Sleep -Seconds 1

# 跳到行尾并添加 ks 参数
[System.Windows.Forms.SendKeys]::SendWait("{END}")
[System.Windows.Forms.SendKeys]::SendWait(" inst.ks=http://192.168.1.1:8080/pigsty-node1.cfg")
Start-Sleep -Seconds 1

# 启动
[System.Windows.Forms.SendKeys]::SendWait("^{F10}")
'@

# 此方法需要虚拟机控制台处于活动状态
# 不推荐用于生产环境
```

---

## 方法 4: 使用 PXE 网络安装 (高级)

### 配置 PXE 服务器

1. 安装 TFTP 和 DHCP 服务器
2. 配置 PXE 启动文件
3. 设置 Kickstart URL

详细配置请参考 Red Hat 文档。

---

## 快速参考

### Kickstart 参数

| 参数 | 说明 |
|------|------|
| `inst.ks=URL` | 指定 Kickstart 文件 URL |
| `inst.ks=cdrom` | 从光驱读取 ks.cfg |
| `inst.ks=hd:DEVICE:/path` | 从硬盘读取 |
| `ip=DHCP` | 使用 DHCP |
| `ip=IP::GW:MASK:HOSTNAME:IFACE:NONE` | 静态 IP |

### 宿主机 IP 查找

```powershell
# 查找宿主机在虚拟交换机网络中的 IP
Get-NetIPAddress -InterfaceAlias "vEthernet (PigstyExternal)" | Select-Object IPAddress
```

### 验证 Kickstart 文件可访问

```powershell
# 在浏览器中访问
http://localhost:8080/pigsty-node1.cfg

# 或使用 curl 测试
curl http://localhost:8080/pigsty-node1.cfg
```

---

## 安装后验证

安装完成后，使用以下命令验证：

```powershell
# 连接到虚拟机
Enter-PSSession -ComputerName 192.168.1.11 -Credential root

# 或使用 SSH
ssh root@192.168.1.11
# 密码: Pigsty@2024
```

在虚拟机内验证：

```bash
# 检查系统版本
cat /etc/os-release

# 检查网络
ip addr
ping 8.8.8.8

# 检查 SSH
systemctl status sshd
```

---

## 文件清单

| 文件 | 说明 |
|------|------|
| `ks.cfg` | 通用 Kickstart 模板 |
| `ks/pigsty-node1.cfg` | 节点1 专用配置 |
| `ks/pigsty-node2.cfg` | 节点2 专用配置 |
| `ks/pigsty-node3.cfg` | 节点3 专用配置 |
| `create_pigsty_vms_auto.ps1` | 自动创建脚本 |
