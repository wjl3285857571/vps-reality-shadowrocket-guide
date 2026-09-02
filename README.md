# VPS Reality 节点与 Shadowrocket DNS 优化流程

这是一套面向初学者的、可回滚的通用操作手册，用于：

1. 在自己有权管理的 Ubuntu/Debian VPS 上部署原生 Xray-core；
2. 配置 VLESS + XTLS Vision + REALITY，监听 TCP 443；
3. 完成服务、端口、防火墙和外部连通性验收；
4. 将节点安全导入 Shadowrocket；
5. 按“一次改一项、每次复测、异常立即回滚”优化 DNS；
6. 检查 DNS、WebRTC、IPv4、IPv6、定位和风险结果；
7. 避免把节点凭据和服务器资料提交到 GitHub。

> 本仓库只包含通用流程与模板。没有任何真实 VPS 地址、域名、节点名称、UUID、REALITY 密钥、Short ID、节点 URI、二维码、密码或 SSH 凭据。

## 为什么整理这套流程

很多 VPS 节点教程只关注“把配置写进去”，却没有回答以下更重要的问题：

- 如何判断服务器是已安装、正在运行，还是已经真正可用？
- 修改 Xray 前如何备份，失败后如何恢复？
- 为什么端口正在监听，Shadowrocket 仍可能无法连接？
- 为什么代理出口已经在境外，DNS 检测仍会出现本地运营商？
- DNS、WebRTC、IPv4、IPv6 和地理定位分别代表什么？
- 什么时候应该修改，什么时候应该停止继续优化？
- 如何把完整经验发布到 GitHub，又不泄露自己的节点凭据？

本仓库把部署过程拆成可观察、可验证、可回滚的小步骤。核心不是追求配置数量，而是保证每一步都有成功标准和失败出口。

## 完成后你会得到什么

按照文档完成后，预期得到：

- 一套不依赖 3X-UI 等管理面板的原生 Xray-core 部署；
- 一个使用 VLESS、XTLS Vision、REALITY 和 TCP 443 的客户端入口；
- 配置校验、systemd 状态、端口监听和外部连接四层服务器证据；
- UFW、Fail2ban、自动安全更新等基础防护；
- 一份只保存在 VPS 本地、权限为 `600` 的客户端参数文件；
- 一套适用于 macOS/iOS Shadowrocket 的逐项 DNS 优化方法；
- IPPure 与 BrowserLeaks 交叉验证方法；
- Xray、防火墙、Fail2ban 和 Shadowrocket DNS 的回滚步骤；
- 一个提交前自动检查节点 URI、UUID、Token、私钥和公网 IP 的扫描脚本。

## 全流程地图

```text
确认授权与目标
    ↓
服务器只读基线检查
    ↓
创建带时间戳的配置与安全备份
    ↓
使用 XTLS 官方安装器安装 Xray-core
    ↓
在 VPS 本地生成 UUID、X25519 密钥与 Short ID
    ↓
写入 VLESS + XTLS Vision + REALITY 配置
    ↓
xray run -test（失败则停止，不重启）
    ↓
启动服务并验证 systemd、443 监听与日志
    ↓
先放行 SSH，再启用 UFW；验证 Fail2ban
    ↓
安全传输客户端参数并导入 Shadowrocket
    ↓
先验证节点，再建立 DNS/WebRTC/IPv4/IPv6 基线
    ↓
主 DNS：system → Cloudflare DoH
    ↓
复测；稳定后再改备用 DNS
    ↓
备用 DNS：system → IP 形式的 Cloudflare DoH
    ↓
IPPure + BrowserLeaks 交叉验证
    ↓
归档非敏感结果，真实节点材料留在私有目录
```

## 核心执行原则

### 1. 一次只改一项

修改主 DNS 时不同时关闭 IPv6；修改防火墙时不同时更改 SSH 端口；更新 Xray 配置时不顺便清理旧服务。否则测试失败后无法判断原因。

### 2. 每项修改后立即复测

复测必须与修改内容对应。例如：

| 修改 | 必须观察的结果 |
|---|---|
| Xray 配置 | `run -test`、服务状态、监听、日志 |
| UFW | SSH 仍可连接、节点端口外部可达 |
| 主 DNS | 节点延迟、网页解析、DNS 检测 |
| 备用 DNS | 本地运营商 DNS 是否消失 |
| IPv6 | 是否出现本地 IPv6 出口 |

### 3. 异常立即回滚

“异常”包括服务无法启动、网站大量无法解析、SSH 有失联风险、节点从正常变为超时，或者泄露检测明显恶化。没有回滚路径的修改不应开始。

### 4. 不把安装等同于成功

本仓库使用以下分层状态：

```text
已安装
→ 配置有效
→ 服务正在运行
→ 端口正在监听
→ 外部可以到达
→ 真实客户端请求成功
→ DNS、WebRTC、IPv4/IPv6 验收通过
```

只有最后一层通过，才能称为完整可用。

## 仓库目录

```text
.
├── README.md
├── SECURITY.md
├── docs
│   ├── 01-完整部署流程.md
│   ├── 02-Shadowrocket与DNS优化.md
│   ├── 03-安全验收与回滚.md
│   └── 04-日本VPS到美国静态ISP-SOCKS5链式代理.md
└── scripts
    ├── install-reality.sh
    ├── verify-server.sh
    └── check-sensitive.sh
```

### 文档说明

- `01-完整部署流程.md`：从新 VPS 基线检查到客户端导入，共包含部署、备份、防火墙、Fail2ban、SSH 安全边界和验收。
- `02-Shadowrocket与DNS优化.md`：解释混合 DNS 的原因，并给出 Mac、iPhone、Wi-Fi、蜂窝网络的逐项修改方法。
- `03-安全验收与回滚.md`：给出六层验收模型、各种异常的回滚方法和凭据泄露后的处理顺序。
- `04-日本VPS到美国静态ISP-SOCKS5链式代理.md`：在保留原日本 Reality 出口的前提下，按客户端身份增加美国静态 ISP SOCKS5 出口，并验证双线路、UDP 与 fail-closed。

### 脚本说明

- `install-reality.sh` 不接受仓库内静态凭据。UUID、X25519 密钥和 Short ID 都在 VPS 本地生成；脚本不会把客户端参数打印到终端。
- `verify-server.sh` 只读检查程序、配置、systemd 和监听状态，不输出服务端私钥或完整配置。
- `check-sensitive.sh` 用于 Git 提交前的第一道检查，但不能代替人工审查。

## 快速开始

先克隆仓库并完整阅读文档：

```bash
git clone https://github.com/<YOUR_GITHUB_NAME>/vps-reality-shadowrocket-guide.git
cd vps-reality-shadowrocket-guide
```

在任何部署操作前运行：

```bash
bash -n scripts/*.sh
bash scripts/check-sensitive.sh
```

服务器部署示例只使用占位符：

```bash
sudo REALITY_TARGET='<REALITY_TARGET>' \
  REALITY_SERVER_NAME='<REALITY_SERVER_NAME>' \
  LISTEN_PORT='443' \
  bash scripts/install-reality.sh
```

不要直接复制尖括号占位符，也不要把真实值写回 Git 仓库。

## 关于“经过验证”的准确含义

这套流程来源于一次完成了服务端、客户端和 DNS 泄露验证的实际工作，但公开仓库没有保留任何实例参数。仓库脚本已通过 Shell 语法、Git 差异和敏感信息检查；由于 VPS 系统版本、Xray 版本、网络路由与 REALITY 目标站点会变化，公开脚本不能替代你在自己服务器上的 `xray run -test` 和真实请求验收。

## 适用范围

- 自己购买并拥有管理权限的 VPS；
- Ubuntu 22.04/24.04 或较新的 Debian；
- 使用 systemd 的服务器；
- macOS/iOS 上的 Shadowrocket；
- 目标是稳定、易验证、可回滚，而不是叠加大量面板和插件。

不适用于未经授权的服务器、共享账户、企业内网穿透或规避组织安全策略。

## 简单架构

```text
浏览器或 App
    ↓
Shadowrocket（规则分流 + 加密 DNS）
    ↓
VLESS + XTLS Vision + REALITY / TCP 443
    ↓
自己的 VPS（原生 Xray-core）
    ↓
互联网
```

## 推荐阅读顺序

1. [完整部署流程](docs/01-完整部署流程.md)
2. [Shadowrocket 与 DNS 优化](docs/02-Shadowrocket与DNS优化.md)
3. [安全、验收与回滚](docs/03-安全验收与回滚.md)
4. [日本 VPS 到美国静态 ISP SOCKS5 链式代理](docs/04-日本VPS到美国静态ISP-SOCKS5链式代理.md)

## 仓库脚本

- `scripts/install-reality.sh`：通用服务器部署脚本。敏感参数只在 VPS 本地生成和保存。
- `scripts/verify-server.sh`：只读验收 Xray 服务、配置与监听端口。
- `scripts/check-sensitive.sh`：提交前扫描可能的节点 URI、UUID、Token 和非示例公网 IP。

脚本不是“无脑一键脚本”。运行前必须先阅读文件，理解变量和回滚点。

## 最小成功标准

只有同时满足以下条件，才算部署成功：

- `xray run -test` 配置校验通过；
- `systemctl is-active xray` 返回 `active`；
- `ss` 确认 Xray 监听预期端口；
- VPS 外部能够建立 TCP 连接；
- 客户端实际通过节点打开网页；
- IPv4/IPv6 出口符合预期；
- DNS 检测不再出现本地运营商解析器；
- WebRTC 没有暴露本地公网地址；
- 所有真实客户端产物仅保存在本地受保护目录。

“安装完成”“服务已注册”或“端口正在监听”都不能单独证明节点可用。

## 官方资料

- [XTLS/Xray-install](https://github.com/XTLS/Xray-install)
- [Xray REALITY 配置文档](https://xtls.github.io/en/config/transports/reality.html)
- [Xray 配置文件说明](https://xtls.github.io/en/config/)
- [Xray 命令行参数](https://xtls.github.io/en/document/command.html)
- [Cloudflare DNS-over-HTTPS](https://developers.cloudflare.com/1.1.1.1/encryption/dns-over-https/make-api-requests/)

## 安全原则

- 不把密码、Token、Cookie、UUID、私钥或节点链接发到聊天、Issue、PR、日志和 Git；
- 不把二维码截图提交到仓库；
- 不在确认密钥登录成功前关闭 SSH 密码登录；
- 不在未验证新配置前删除旧配置；
- 每次只改一项，并保留明确回滚路径；
- 对版本相关字段，以当前 Xray 官方文档和 `xray run -test` 的结果为准。
