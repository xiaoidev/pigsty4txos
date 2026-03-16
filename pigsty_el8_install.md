# Pigsty EL8 在线安装指南

> 适用于 RHEL 8 / CentOS 8 / RockyLinux 8 / AlmaLinux 8

---

## 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | RHEL 8.x / CentOS 8.x / RockyLinux 8.x / AlmaLinux 8.x |
| 架构 | x86_64 / aarch64 |
| 内存 | 至少 2GB（推荐 4GB+） |
| 磁盘 | /data 目录至少 20GB |
| 网络 | 需要互联网访问 |
| 权限 | root 或 sudo 免密权限 |

---

## 安装步骤

### 第一步：下载 Pigsty 源码

```bash
# 方式一：使用安装脚本（推荐）
curl -fsSL https://repo.pigsty.cc/get | bash

# 方式二：指定版本
curl -fsSL https://repo.pigsty.cc/get | bash -s v4.2.1

# 方式三：手动下载
curl -fsSL https://repo.pigsty.cc/src/v4.2.1/pigsty-v4.2.1.tgz -o pigsty.tgz
tar -xf pigsty.tgz
cd pigsty
```

### 第二步：执行 Bootstrap

```bash
cd ~/pigsty
./bootstrap
```

Bootstrap 脚本会：
1. 检测操作系统版本
2. 配置软件源（EL8 使用 EPEL、PGDG 等）
3. 安装 Ansible 及依赖

**EL8 特定配置：**

Bootstrap 会自动配置以下软件源：
- **AppStream** - EL8 应用流
- **BaseOS** - EL8 基础系统
- **EPEL** - Extra Packages for Enterprise Linux
- **PGDG** - PostgreSQL 官方仓库
- **Pigsty** - Pigsty 扩展仓库

### 第三步：生成配置

```bash
# 使用配置向导
./configure -g

# 或指定参数
./configure -i <内网IP> -c <配置模板>

# 常用配置模板
# - rich: 完整功能模板（推荐）
# - mini: 最小化模板
# - demo: 演示模板
```

### 第四步：执行部署

```bash
# 完整部署
./deploy.yml

# 或分步部署
./node.yml      # 节点配置
./infra.yml     # 基础设施
./pgsql.yml     # PostgreSQL 集群
```

---

## EL8 特定配置

### 软件源配置

在 `pigsty.yml` 中，EL8 使用以下软件源：

```yaml
repo_upstream:
  - { name: pigsty-local   ,description: 'Pigsty Local'      ,module: local  ,releases: [8,9,10] ,arch: [x86_64, aarch64] ,baseurl: { default: 'https://repo.pigsty.cc/pigsty' } }
  - { name: pigsty-infra   ,description: 'Pigsty INFRA'      ,module: infra  ,releases: [8,9,10] ,arch: [x86_64, aarch64] ,baseurl: { default: 'https://repo.pigsty.cc/yum/el$releasever/$basearch' } }
  - { name: pigsty-pgsql   ,description: 'Pigsty PGSQL'      ,module: pgsql  ,releases: [8,9,10] ,arch: [x86_64, aarch64] ,baseurl: { default: 'https://repo.pigsty.cc/yum/el$releasever/$basearch' } }
  - { name: epel           ,description: 'EPEL'              ,module: node   ,releases: [8,9]    ,arch: [x86_64, aarch64] ,baseurl: { default: 'https://dl.fedoraproject.org/pub/epel/$releasever/Everything/$basearch/' ,china: 'https://mirrors.aliyun.com/epel/$releasever/Everything/$basearch/' } }
  - { name: pgdg-common    ,description: 'PGDG Common'       ,module: pgsql  ,releases: [8,9,10] ,arch: [x86_64, aarch64] ,baseurl: { default: 'https://download.postgresql.org/pub/repos/yum/common/redhat/rhel-$releasever-$basearch' ,china: 'https://mirrors.aliyun.com/postgresql/repos/yum/common/redhat/rhel-$releasever-$basearch' } }
  - { name: pgdg-el8fix    ,description: 'PostgreSQL EL8FIX' ,module: pgsql  ,releases: [8]      ,arch: [x86_64, aarch64] ,baseurl: { default: 'https://download.postgresql.org/pub/repos/yum/common/pgdg-centos8-sysupdates/redhat/rhel-8-$basearch/' } }
```

### 中国区镜像加速

如果在中国大陆，使用 `-r china` 参数：

```bash
./configure -g -r china
```

这将使用阿里云镜像加速下载。

---

## PostgreSQL 版本支持

EL8 支持以下 PostgreSQL 版本：

| 版本 | 状态 |
|------|------|
| PostgreSQL 13 | ✅ 支持 |
| PostgreSQL 14 | ✅ 支持 |
| PostgreSQL 15 | ✅ 支持 |
| PostgreSQL 16 | ✅ 支持 |
| PostgreSQL 17 | ✅ 支持 |
| PostgreSQL 18 | ✅ 支持 |

指定 PostgreSQL 版本：

```bash
./configure -g -v 16
```

---

## 常见问题

### 1. DNF 模块冲突

EL8 使用 DNF 模块，可能需要禁用 PostgreSQL 模块：

```bash
sudo dnf -qy module disable postgresql
```

### 2. Python 版本

EL8 默认 Python 3.6，Pigsty 会自动安装 Python 3.9+：

```bash
# 检查 Python 版本
python3 --version
```

### 3. SELinux

建议临时禁用 SELinux 或设置为 Permissive：

```bash
sudo setenforce 0
# 或永久禁用
sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
```

### 4. 防火墙

开放必要端口：

```bash
# Pigsty 默认端口
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=5432-5438/tcp
sudo firewall-cmd --permanent --add-port=6379/tcp
sudo firewall-cmd --permanent --add-port=9000-9001/tcp
sudo firewall-cmd --reload
```

---

## 自制 EL8 离线包

如果您需要在多个 EL8 环境部署，可以在首次在线安装后制作离线包：

```bash
# 首次在线安装完成后
cd ~/pigsty

# 创建离线包
./cache.yml -l infra

# 离线包位置
ls -la dist/v4.2.1/pigsty-pkg-v4.2.1.el8.x86_64.tgz
```

将离线包复制到其他 EL8 服务器：

```bash
# 在目标服务器上
./bootstrap -p /path/to/pigsty-pkg-v4.2.1.el8.x86_64.tgz
./configure -g
./deploy.yml
```

---

## 验证安装

```bash
# 检查服务状态
systemctl status patroni
systemctl status pgbouncer
systemctl status haproxy

# 连接数据库
psql -h localhost -U dbuser_dba -d postgres

# 访问监控
# Grafana: http://<服务器IP>/grafana
# 默认用户: admin / pigsty
```

---

## 参考链接

- 官方文档：https://pigsty.cc/docs/
- 安装指南：https://pigsty.cc/docs/setup/install/
- 配置参考：https://pigsty.cc/docs/reference/params/
- GitHub：https://github.com/pgsty/pigsty

---

> 文档版本：v4.2.1
> 更新日期：2026-03-16
