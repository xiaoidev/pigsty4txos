# Pigsty 官方文档完整解析

> 文档来源：https://pigsty.cc/docs/
> 版本：v4.2.1
> 整理日期：2026-03-16

---

## 目录

1. [项目概述](#项目概述)
2. [核心概念](#核心概念)
3. [系统架构](#系统架构)
4. [快速上手](#快速上手)
5. [模块详解](#模块详解)
6. [高可用与备份](#高可用与备份)
7. [安全合规](#安全合规)
8. [参考信息](#参考信息)

---

## 项目概述

### 什么是 Pigsty？

**Pigsty** = **P**ost**G**res **S**TYle —— "PostgreSQL In Great STYle"

> 开箱即用、本地优先的 PostgreSQL 发行版，开源 RDS 替代方案

### 核心定位

- **Postgres**: 世界上最先进的开源关系型数据库
- **Infras**: 完整的基础设施支持
- **Graphics**: 强大的可视化监控系统
- **Service**: 生产级服务管理
- **Toolbox**: 丰富的工具集

### 为什么需要 Pigsty？

PostgreSQL 是一个足够完美的数据库内核，但它需要更多工具与系统的配合才能成为一个足够好的数据库服务。在生产环境中，您需要管理数据库的方方面面：

- 高可用
- 备份恢复
- 监控告警
- 访问控制
- 参数调优
- 扩展安装
- 连接池化
- 负载均衡

Pigsty 为您提供：

1. **开箱即用的 PostgreSQL 发行版** - 深度整合 451 扩展插件
2. **故障自愈的高可用架构** - RTO < 45s，RPO ≈ 0
3. **完整的时间点恢复能力** - pgBackRest + MinIO
4. **灵活的服务接入** - HAProxy + Pgbouncer + VIP
5. **惊艳的可观测性** - Prometheus + Grafana
6. **声明式的配置管理** - 基础设施即代码
7. **模块化的架构设计** - 按需组合
8. **扎实的安全最佳实践** - 等保三级合规

---

## 核心概念

### Pigsty 不是什么？

1. **不是传统的 PaaS** - 不提供基础硬件资源
2. **不是容器编排系统** - 直接运行在操作系统之上
3. **不是通用的数据库管理工具** - 专注于 PostgreSQL 生态
4. **不会锁定您** - 基于开源组件，可随时脱离

### PostgreSQL 部署方式演进

```
手工部署时代 → 托管数据库时代(RDS) → 本地 RDS 时代(Pigsty)
```

**Pigsty 结合了前两种方式的优点：**

- 自动化程度高：一键部署，自动配置，故障自愈
- 完全自主可控：运行在自己的基础设施上
- 成本极低：以接近纯硬件的成本运行企业级服务
- 功能完整：无限制使用 PostgreSQL 全部能力

---

## 系统架构

### 架构图

```
┌─────────────────────────────────────────────────────────────┐
│                        Pigsty 架构                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐        │
│  │ Grafana │  │ AlertMgr│  │ Nginx   │  │ DNS/NTP │        │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘        │
│       └────────────┴────────────┴────────────┘             │
│                      │ INFRA 模块                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐        │
│  │ Patroni │  │Pgbouncer│  │pgBackRest│ │ Exporter│        │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘        │
│       └────────────┴────────────┴────────────┘             │
│                      │ PGSQL 模块                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐        │
│  │  etcd   │  │  MinIO  │  │  Redis  │  │ Docker  │        │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘        │
│       │            │           │           │               │
│    ETCD模块    MINIO模块    REDIS模块   DOCKER模块          │
├─────────────────────────────────────────────────────────────┤
│                      NODE 模块                              │
│         目标服务器配置、VIP、HAProxy、监控组件               │
└─────────────────────────────────────────────────────────────┘
```

### 六大核心模块

| 模块 | 功能 | 核心组件 | 典型场景 |
|------|------|----------|----------|
| **PGSQL** | 高可用 PostgreSQL | PostgreSQL、Patroni、Pgbouncer、HAProxy | 业务数据库 |
| **INFRA** | 基础设施服务 | Prometheus、Grafana、Nginx、AlertManager | 监控中心 |
| **NODE** | 节点管理 | node_exporter、Vector、Docker | 所有服务器 |
| **ETCD** | 分布式共识 | Etcd 集群 | HA 必需 |
| **REDIS** | 缓存服务 | Redis 主从/哨兵/集群 | 应用缓存 |
| **MINIO** | 对象存储 | MinIO 分布式存储 | 远程备份 |

### 模块依赖关系

```
所有模块 → NODE（节点必须先被纳管）
NODE → INFRA（弱依赖，使用本地软件源时）
PGSQL → ETCD（HA 必需）
PGSQL → MINIO（可选备份）
```

### 部署模式

#### 单机部署

```yaml
# 开发测试环境，一台机器搞定所有
all:
  children:
    infra:
      hosts: { 10.10.10.10: { infra_seq: 1 } }
    etcd:
      hosts: { 10.10.10.10: { etcd_seq: 1 } }
    pg-meta:
      hosts: { 10.10.10.10: { pg_seq: 1, pg_role: primary } }
```

#### 高可用集群

```yaml
# 三节点高可用 PostgreSQL
pg-cluster:
  hosts:
    10.10.10.11: { pg_seq: 1, pg_role: primary }
    10.10.10.12: { pg_seq: 2, pg_role: replica }
    10.10.10.13: { pg_seq: 3, pg_role: replica }
  vars:
    pg_cluster: pg-cluster
```

---

## 快速上手

### 安装命令

```bash
# 安装最新版本
curl -fsSL https://repo.pigsty.cc/get | bash

# 安装指定版本
curl -fsSL https://repo.pigsty.cc/get | bash -s v4.2.1
```

### 三步部署

```bash
# 1. 安装 Pigsty 与依赖
curl -fsSL https://repo.pigsty.cc/get | bash

# 2. 生成配置
cd ~/pigsty
./configure -g    # 使用配置向导生成配置文件

# 3. 执行部署
./deploy.yml      # 执行部署剧本
```

### 系统要求

| 项目 | 要求 |
|------|------|
| 节点 | 单节点，至少 1C2G |
| 磁盘 | /data 作为默认主挂载点，建议 xfs |
| 系统 | Linux x86_64 / aarch64，EL / Debian / Ubuntu |
| 网络 | 静态 IPv4 内网地址 |
| SSH | 通过公钥 nopass SSH 登陆 |
| SUDO | sudo 权限，最好免密 |

### 配置向导参数

| 参数 | 说明 |
|------|------|
| `-i|--ip` | 当前主机的首要内网 IP 地址 |
| `-c|--conf` | 指定使用的配置模板 |
| `-v|--version` | 指定 PostgreSQL 大版本 |
| `-r|--region` | 上游软件源区域 (default|china|europe) |
| `-g` | 生成随机密码 |

---

## 模块详解

### PGSQL 模块

PostgreSQL 数据库核心模块，提供：

- **高可用架构** - Patroni + Etcd + HAProxy
- **连接池** - PgBouncer
- **备份恢复** - pgBackRest
- **监控** - PG Exporter + Grafana

#### 身份参数

```yaml
pg_cluster: pg-meta      # 集群名称
pg_seq: 1                # 实例序号
pg_role: primary         # 角色：primary/replica/offline
```

#### 实例角色

| 角色 | 说明 |
|------|------|
| primary | 读写主库 |
| replica | 只读从库 |
| offline | 离线从库（ETL/分析） |
| sync | 同步备库 |
| delayed | 延迟从库 |

#### 剧本命令

```bash
./pgsql.yml        # 初始化 PostgreSQL 集群
./pgsql-rm.yml     # 移除 PostgreSQL 集群
./pgsql-user.yml   # 创建业务用户
./pgsql-db.yml     # 创建业务数据库
bin/pgsql-add      # 添加集群
bin/pgsql-rm       # 移除集群
```

### INFRA 模块

基础设施模块，提供：

| 组件 | 端口 | 描述 |
|------|------|------|
| Nginx | 80/443 | Web 服务门户 |
| Grafana | 3000 | 可视化平台 |
| VictoriaMetrics | 8428 | 时序数据库 |
| VictoriaLogs | 9428 | 日志数据库 |
| VMAlert | 8880 | 告警规则评估 |
| AlertManager | 9059 | 告警聚合分发 |
| BlackboxExporter | 9115 | 黑盒探测 |
| DNSMASQ | 53 | DNS 服务器 |
| Chronyd | 123 | NTP 时间服务器 |

### NODE 模块

节点管理模块，负责：

- 配置目标服务器
- 纳管主机节点
- VIP 管理
- HAProxy 配置
- 监控组件安装

### ETCD 模块

分布式配置存储，用于：

- PostgreSQL 高可用共识
- Patroni 领导者选举
- VIP 绑定信息存储

### REDIS 模块

缓存服务模块，支持：

- 主从复制模式
- 哨兵高可用模式
- 原生集群模式

### MINIO 模块

对象存储模块，用于：

- PostgreSQL 备份存储
- S3 兼容 API
- 分布式存储

---

## 高可用与备份

### 高可用 (HA)

#### 核心指标

| 指标 | 默认值 | 说明 |
|------|--------|------|
| RTO | < 45s | 故障恢复时间 |
| RPO | < 1MB | 数据损失量 |
| 从库故障 RPO | 0 | 无数据损失 |
| 从库故障 RTO | ≈ 0 | 闪断 |

#### 工作原理

```
PostgreSQL → 流复制 → 从库
    ↓
Patroni → 管理 PostgreSQL 进程
    ↓
Etcd → 分布式配置存储 + 领导者选举
    ↓
HAProxy → 健康检查 + 流量路由
    ↓
vip-manager → VIP 绑定
```

#### 故障切换流程

1. Patroni 检测主库故障
2. 触发新一轮领导者选举
3. 最健康的从库胜出（LSN 最高）
4. 胜选从库提升为新主库
5. HAProxy 自动路由流量到新主库

### 时间点恢复 (PITR)

#### 核心组件

- **pgBackRest** - 备份管理工具
- **MinIO/S3** - 远程备份存储

#### 备份模式

| 模式 | 说明 |
|------|------|
| 全量备份 | 数据库完整快照 |
| 增量备份 | 与上次全量的差异 |
| 差异备份 | 与上次备份的差异 |

#### 恢复命令

```bash
pg-pitr                                 # 恢复到 WAL 结束位置
pg-pitr -i                              # 恢复到最近备份
pg-pitr --time="2022-12-30 14:44:44"    # 恢复到指定时间点
pg-pitr --name="my-restore-point"       # 恢复到命名恢复点
pg-pitr --lsn="0/7C82CB8"               # 恢复到指定 LSN
pg-pitr --xid="1234567"                 # 恢复到指定事务 ID
```

---

## 安全合规

### 安全架构

```
🔒 第 4 层：数据安全 - 数据校验 + 备份加密 + 审计日志
👤 第 3 层：访问控制 - 角色系统 + 对象权限 + 数据库隔离
🔑 第 2 层：身份认证 - HBA 规则 + SCRAM-SHA-256 + 证书认证
🌐 第 1 层：网络安全 - 防火墙 + SSL/TLS + HAProxy 代理
```

### 默认安全配置

| 特性 | 默认配置 |
|------|----------|
| 密码加密 | scram-sha-256 |
| SSL 支持 | 启用 |
| 本地 CA | 自动生成 |
| HBA 分层 | 按来源控制 |
| 角色系统 | 四层权限 |
| 数据校验 | 启用 |
| 审计日志 | 启用 |

### 四层角色系统

```
🔴 dbrole_admin（管理员）
    └── 继承 dbrole_readwrite
    └── 可创建/删除/修改对象 DDL

🟡 dbrole_readwrite（读写）
    └── 继承 dbrole_readonly
    └── 可以 INSERT/UPDATE/DELETE

🟢 dbrole_readonly（只读）
    └── 可以 SELECT 所有表

🔵 dbrole_offline（离线）
    └── 只能访问离线实例
```

### 合规对照

#### 等保三级

| 安全要求 | Pigsty 支持 |
|----------|-------------|
| 身份鉴别唯一性 | ✅ |
| 口令复杂度 | ✅ (启用 passwordcheck) |
| 双因素认证 | ✅ (证书 + 密码) |
| 访问控制 | ✅ |
| 最小权限原则 | ✅ |
| 通信加密 | ✅ |
| 审计日志 | ✅ |
| 数据完整性 | ✅ |
| 备份恢复 | ✅ |

---

## 服务接入

### 四种默认服务

| 服务 | 端口 | 目标 | 连接池 | 用途 |
|------|------|------|--------|------|
| primary | 5433 | 主库 | ✅ | 核心业务读写 |
| replica | 5434 | 从库 | ✅ | 只读查询、报表 |
| default | 5436 | 主库 | ❌ | DDL、管理操作 |
| offline | 5438 | 离线库 | ❌ | ETL、分析查询 |

### 接入方式

```bash
# DNS 接入（推荐）
psql postgres://user@pg-test:5433/mydb

# VIP 接入
psql postgres://user@10.10.10.3:5433/mydb

# 直连实例
psql postgres://user@pg-test-1:5432/mydb
```

---

## 监控系统

### 技术栈

| 组件 | 作用 |
|------|------|
| Grafana | 可视化监控面板 |
| VictoriaMetrics | 时序指标采集存储 |
| VictoriaLogs | 结构化日志采集索引 |
| VMAlert | 告警规则执行 |
| Alertmanager | 告警消息通知 |
| Exporter/Agent | 指标暴露、日志转发 |

### 监控面板

Pigsty 提供 26+ PostgreSQL 相关监控面板：

- PGSQL Overview - 集群概览
- PGSQL Cluster - 集群详情
- PGSQL Instance - 实例详情
- PGSQL Database - 数据库监控
- PGSQL Replication - 复制监控
- PGSQL PITR - 备份恢复监控
- PGSQL Pgbouncer - 连接池监控
- PGSQL Patroni - 高可用监控

### 纳管方式

| 模式 | 适用场景 |
|------|----------|
| FULL | 数据库由 Pigsty 直接部署托管 |
| MANAGED | 现有 PostgreSQL 集群，节点可 SSH 管理 |
| RDS | 仅能通过连接串访问的云数据库 |

---

## 参考信息

### 支持的操作系统

- EL7/EL8/EL9/EL10 (RHEL, CentOS, Rocky, Alma)
- Ubuntu 22.04/24.04
- Debian 12/13

### PostgreSQL 版本支持

支持 PostgreSQL 13-18 版本

### 扩展插件

Pigsty 整合了 451+ PostgreSQL 扩展插件，包括：

| 扩展 | 用途 |
|------|------|
| PostGIS | 地理空间 |
| TimescaleDB | 时序数据 |
| pgvector | 向量嵌入 |
| Citus | 水平分布式 |
| Apache AGE | 图数据库 |
| pg_graphql | GraphQL |
| pg_bm25 | 全文检索 |
| PostgresML | 机器学习 |

### 成本对比

| 方式 | 折合每年（万元） |
|------|------------------|
| IDC 托管服务器 (64C/384G/3.2TB) | 3.0 ~ 4.5 |
| 阿里云 RDS PG 高可用版 | 25 ~ 50 |
| AWS RDS PG 高可用版 | 160 ~ 217 |

### 同类对比

| 指标 | Pigsty | 阿里云 RDS | AWS RDS |
|------|--------|------------|---------|
| 扩展插件 | 451+ 自由加装 | 受限 | 受限 |
| 监控指标 | 638+ | 8 | 99 |
| 高可用 | Patroni/etcd | 需高可用版 | 需高可用版 |
| 连接池 | Pgbouncer | 独立收费 | 独立收费 |
| 负载均衡 | HAProxy | 独立收费 | 独立收费 |

---

## 附录

### 文件结构

```
pigsty/
├── bootstrap          # 引导脚本
├── configure          # 配置生成脚本
├── pigsty.yml         # 主配置文件
├── deploy.yml         # 主部署入口
├── bin/               # 命令行工具
├── roles/             # Ansible Roles
├── conf/              # 配置模板
└── files/
    ├── grafana/       # 仪表盘 JSON
    ├── postgres/      # PG 脚本
    └── victoria/      # 监控规则
```

### 常用命令速查

```bash
# 集群管理
bin/pgsql-add pg-test      # 创建集群
bin/pgsql-rm pg-test       # 移除集群
bin/node-add 10.10.10.11   # 添加节点
bin/node-rm 10.10.10.11    # 移除节点

# 用户数据库管理
bin/pgsql-user pg-meta dbuser_meta   # 创建用户
bin/pgsql-db pg-meta meta            # 创建数据库

# 备份恢复
/pg/bin/pg-backup full     # 全量备份
/pg/bin/pg-backup incr     # 增量备份
pg-pitr --time="..."       # 时间点恢复

# 服务管理
systemctl reload patroni   # 重载 Patroni
systemctl reload pgbouncer # 重载连接池
```

### 相关链接

- 官网：https://pigsty.cc
- 文档：https://pigsty.cc/docs/
- GitHub：https://github.com/pgsty/pigsty
- 演示：https://demo.pigsty.cc

---

> 本文档基于 Pigsty v4.2.1 官方文档整理
