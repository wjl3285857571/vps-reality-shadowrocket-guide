# 04｜日本 VPS 到美国静态 ISP SOCKS5 链式代理

本文介绍如何在保留原 VLESS + XTLS Vision + REALITY 日本出口的同时，为另一个客户端身份增加美国静态 ISP SOCKS5 出口。所有尖括号内容都是占位符，不能原样用于生产配置。

## 1. 适用场景

已有结构：

```text
客户端 → VLESS/REALITY → 日本 VPS Xray → direct → 日本出口
```

希望增加：

```text
新客户端 → VLESS/REALITY → 日本 VPS Xray → SOCKS5 → 美国静态 ISP 出口
```

美国服务商只提供 `host`、`port`、`username` 和 `password` 时，它是代理服务，不是可登录的 VPS。不要尝试对代理地址执行 SSH，也不要在代理地址上安装 Xray。

Xray 官方文档明确提示 SOCKS 协议本身不加密，不适合作为不受信任公网链路上的加密层。使用商业静态 SOCKS5 时，应确认服务商可信，并让敏感业务继续使用 HTTPS/TLS；链式代理改变出口，不等于日本 VPS 到美国上游之间获得额外端到端加密。

## 2. 设计目标

- 原客户端和日本出口不变；
- 新客户端身份只走美国 SOCKS5；
- 美国上游故障时，新客户端直接失败，不回落到日本 `direct`；
- 不修改 VPS 的默认路由、系统 DNS、SSH、软件更新或监控流量；
- 不在 Git、聊天、截图或普通日志中记录真实代理参数和节点材料。

最小变更方案是复用现有 443 入站，为新线路增加独立客户端身份，再按该身份的 `email` 路由到新的 SOCKS 出站。

## 3. 修改前检查

先确认现有配置和服务，不要根据旧教程猜测字段：

```bash
sudo /usr/local/bin/xray version
sudo systemctl is-active xray
sudo systemctl is-enabled xray
sudo ss -lntp
sudo /usr/local/bin/xray run -test \
  -config /usr/local/etc/xray/config.json
```

只做结构级检查：

- 入站数量、协议、端口、传输和安全类型；
- 客户端数量以及是否已有 `email`；
- 出站 tag 顺序；
- 路由规则数量和已有匹配条件；
- 是否存在 balancer、fallback 或全局代理逻辑。

不要打印完整配置，因为其中可能包含 UUID、REALITY 私钥、Short ID 和其他节点凭据。

## 4. 先验证 SOCKS5 上游

修改 Xray 前，直接验证上游：

1. TCP 端口可达；
2. 用户名/密码认证成功；
3. 可以连接 HTTPS 目标；
4. 出口国家和地址符合购买信息；
5. 出口与日本 VPS 不同；
6. 如业务需要 UDP，验证 `UDP ASSOCIATE` 和实际 UDP DNS；
7. 分别确认 IPv4 与 IPv6 能力，不要假设静态 IPv4 代理同时支持 IPv6。

代理参数应由操作者在服务器本地输入到 `600 root:root` 临时文件，测试和配置生成结束后删除。不要把认证串放入 shell 历史、命令行参数、Git 或聊天。

## 5. 配置结构

### 5.1 新客户端身份

在现有 VLESS 入站的 `settings.clients` 中保留原对象，再增加一个新对象：

```json
{
  "id": "<NEW_CLIENT_UUID>",
  "flow": "xtls-rprx-vision",
  "email": "<US_ISP_CLIENT_EMAIL>"
}
```

`email` 在这里是路由标识，不应包含真实姓名、账户名或代理凭据。

### 5.2 SOCKS 出站

在现有 `direct`、`blocked` 之后增加：

```json
{
  "protocol": "socks",
  "tag": "us-isp",
  "settings": {
    "address": "<SOCKS_HOST>",
    "port": 1080,
    "user": "<SOCKS_USERNAME>",
    "pass": "<SOCKS_PASSWORD>"
  }
}
```

把示例端口替换为服务商提供的实际端口，但不要把真实配置提交到仓库。

保留 `direct` 为第一个出站。没有命中任何规则的原客户端会继续使用原默认出口。

### 5.3 精确路由

增加一条按客户端身份匹配的规则：

```json
{
  "type": "field",
  "user": ["<US_ISP_CLIENT_EMAIL>"],
  "outboundTag": "us-isp"
}
```

不要为这条线路添加 `direct` fallback。没有 fallback 或 balancer 时，上游连接失败会使新线路失败，从而避免泄漏到日本出口。

## 6. 安全部署

1. 创建 root-only 时间戳备份，至少包含 Xray 配置和相关 systemd 服务文件。
2. 在单独候选文件中生成完整配置，候选文件必须以 `.json` 结尾。
3. 检查候选文件权限和所有者，不回显内容。
4. 使用当前 Xray 二进制运行 `run -test`。
5. 检查通过后再原子替换实际配置。
6. 重启 `xray.service`，检查 active/enabled、监听端口和新增日志。
7. 立即验证原客户端，确认没有回归。

Xray 会根据文件扩展名判断配置格式。同一份 JSON 内容如果以非 `.json` 后缀暂存，可能被错误解析；候选配置应始终保留 `.json` 结尾。

## 7. 双线路验收

服务器 active 或端口监听不能证明链路正确。至少完成以下真实请求：

| 客户端身份 | 预期结果 |
|---|---|
| 原客户端 | 请求成功，仍为日本出口 |
| 新客户端 | 请求成功，为美国静态 ISP IPv4 出口 |
| 两个客户端 | 出口地址不同 |

同时检查：

- 新旧客户端都能完成 VLESS/REALITY 握手；
- 新线路访问域名时使用符合预期的解析路径；
- 美国上游的 UDP 能力与业务要求一致；
- 美国线路不支持 IPv6 时，IPv6-only 请求应失败，不能借用日本 IPv6。

## 8. fail-closed 验证

不要直接破坏生产代理。可以复制配置到隔离测试实例，把测试副本中的 `us-isp` 地址临时改为本机不可达端口，然后分别发起请求：

```text
原客户端 → 成功
新客户端 → 失败
```

如果新客户端仍能访问并显示日本出口，说明存在错误的回退、路由未命中或测试身份不一致，应停止交付并修复。

## 9. Shadowrocket 导入

为新客户端生成独立 VLESS URI，至少应包含与当前 REALITY 配置匹配的 UUID、地址、端口、flow、security、SNI、public key、Short ID、fingerprint 和传输类型。

安全传输方式：

1. URI 和人工核对文本只保存在 VPS root-only 文件中；
2. 如需二维码，在可信本机离线生成，不使用在线二维码网站；
3. 二维码文件保持 `600 root:root`，通过 SFTP 下载或预览；
4. `.uri` 和 `.png` 是文件，不是 Bash 命令，不能直接执行路径；
5. 导入后分别测试网页、API、视频、出口国家、DNS、WebRTC 和 IPv6；
6. 真机验收完成后删除临时 SSH 公钥和不再需要的客户端产物。

## 10. 常见误区

- 把静态代理当成美国 VPS，尝试 SSH 登录；
- 为第二条线路再开一个冲突的 443 入站；
- 把 `us-isp` 放在第一个默认出站，意外接管原客户端；
- 修改系统默认路由，让 SSH 和系统服务一起走美国代理；
- 只看 `systemctl active`，不做真实出口请求；
- 上游失败后仍允许回落到日本出口；
- 把完整 URI、二维码、UUID、代理认证串或配置提交到 GitHub；
- 在终端直接输入文件路径，误把 URI/PNG 当成可执行程序。

## 11. 回滚

出现服务失败、原客户端中断或出口不符合预期时：

1. 保留 SSH 会话，不修改 UFW 和 SSH；
2. 恢复实施前备份配置；
3. 使用当前 Xray 版本重新运行配置检查；
4. 检查通过后重启服务；
5. 验证原客户端、443 监听、日志和真实日本出口。

## 12. 最小交付标准

- 原日本客户端真实请求成功；
- 新美国客户端真实请求成功；
- 新旧出口不同且国家符合预期；
- 美国上游故障时新线路 fail-closed；
- UDP 与 IPv6 行为已经单独记录；
- Shadowrocket 真机测试通过；
- 临时 SSH 公钥已撤销并验证无法登录；
- Git 和文档中没有任何真实基础设施或节点凭据。

## 官方资料

- [Xray SOCKS 出站](https://xtls.github.io/en/config/outbounds/socks.html)
- [Xray 路由](https://xtls.github.io/en/config/routing.html)
- [Xray VLESS 出站与客户端字段](https://xtls.github.io/en/config/outbounds/vless.html)
- [Xray REALITY](https://xtls.github.io/en/config/transports/reality.html)
