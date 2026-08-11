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
