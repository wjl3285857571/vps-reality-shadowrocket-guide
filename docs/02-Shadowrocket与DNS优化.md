# 02｜Shadowrocket 与 DNS 优化

本流程适用于节点已经正常使用，但 DNS 检测仍出现本地运营商解析器的情况。

## 1. 先理解什么是 DNS 泄露

检测到本地运营商 DNS，不一定代表浏览器真实公网 IP 已经泄露。

需要分开看：

- 浏览器出口 IP：网页看到的连接来源；
- DNS 出口：负责解析域名的递归解析器；
- WebRTC：浏览器实时通信接口可能暴露的地址；
- IPv6：可能绕过只覆盖 IPv4 的代理；
- 定位：网站数据库或浏览器权限得到的位置。

典型问题是：浏览器出口在 VPS 所在地区，但一部分域名仍由本地运营商 DNS 解析。这会降低网络环境的一致性，也可能让本地网络观察到访问域名。

## 2. 为什么会出现“运营商 + Cloudflare”混合 DNS

常见配置是：

```ini
dns-server = system
fallback-dns-server = system
```

`system` 会使用 macOS/iOS 或路由器下发的 DNS，最终可能由本地运营商解析。与此同时，代理类域名可能在远端节点解析，于是检测网站同时看到：

```text
本地运营商 DNS
远端 Cloudflare DNS
```

这通常是客户端 DNS 路径造成的，不应直接归因于 VPS 故障。

## 3. 修改前备份

### 3.1 Shadowrocket 内部备份

优先使用 Shadowrocket 自带的配置导出或复制功能，把当前正在使用的配置保存到仅自己可访问的位置。

### 3.2 macOS 容器备份

Shadowrocket 数据可能位于以下容器：

```text
~/Library/Containers/com.liguangming.Shadowrocket/
~/Library/Containers/com.liguangming.Shadowrocket.PacketTunnel/
~/Library/Group Containers/group.com.liguangming.Shadowrocket/
```

这些目录可能包含真实节点材料，备份目录必须权限受限，且必须加入 `.gitignore`。不要因为普通压缩工具报错就假装备份成功；应校验备份文件数量、大小和可读性。

## 4. 建立修改前基线

记录不敏感状态：

```text
当前配置名称
全局路由模式
当前节点是否选中
Shadowrocket 开关是否开启
节点延迟
主 DNS
备用 DNS
IPv6 是否开启
IPv4/IPv6 出口地区
DNS 运营商和地区
WebRTC 是否泄露
```

建议检测：

- [IPPure DNS 检测](https://ippure.com/DNS-Leak-Detect.html)
- [BrowserLeaks DNS](https://browserleaks.com/dns)
- [BrowserLeaks IP](https://browserleaks.com/ip)

不要只看一次测试，也不要只看一个网站的地理数据库。

## 5. 一次只改一项

### 第一次：修改主 DNS

保持 Shadowrocket 开启，进入：

```text
配置 → 当前配置的详情 → 通用 → DNS 覆写
```

把主 DNS 从：

```ini
system
```

改为：

```ini
https://cloudflare-dns.com/dns-query
```

备用 DNS 暂时保持 `system`。保存后立即测试：

1. Shadowrocket 是否仍开启；
2. 当前节点是否未切换；
3. 连通性测试是否正常；
4. 网页是否能打开；
5. IPPure DNS 是否改善。

保留系统备用 DNS 的目的，是让第一次修改失败时仍能解析域名。这是诊断步骤，不一定是最终状态。

### 第二次：修改备用 DNS

如果第一次修改后连接稳定，但仍看到本地运营商 DNS，把备用 DNS 从：

```ini
system
```

改为：

```ini
https://1.1.1.1/dns-query
```

IP 形式的 DoH 地址减少了解析 DoH 服务域名时对系统 DNS 的依赖。

保存后重复完全相同的测试。不要在这一步顺手修改 IPv6、全局路由或规则。

## 6. 如何判断优化成功

可接受结果应同时满足：

- Shadowrocket 始终开启；
- 当前节点没有切换；
- 延迟只出现正常波动；
- IPv4/IPv6 出口仍符合预期；
- IPPure 不再显示本地运营商 DNS；
- BrowserLeaks 交叉验证只显示预期的公共 DNS 提供商；
- WebRTC 不暴露本地公网地址；
- 普通网页和常用应用工作正常。

Cloudflare 使用 Anycast，同一组地址在不同数据库里可能被标成日本、美国或其他注册地。判断重点是运营商是否仍为 Cloudflare，以及独立检测是否显示实际请求位置一致；不要只根据单个 IP 数据库的国家标签下结论。

## 7. 什么时候立即回滚

出现任一情况就恢复上一阶段配置：

- 大量网站无法解析；
- 节点从可用变为超时；
- 延迟持续显著升高；
- IPv4 或 IPv6 出现本地出口；
- DNS 检测结果比修改前更混乱；
- Shadowrocket 配置无法保存或编译；
- 常用国内网站明显异常。

回滚时同样一次只恢复一项，恢复后复测。

## 8. 软件自带配置是否要整套替换

不要因为配置名是 `default.conf` 就认定它不好。先检查：

- 规则是否以域名规则为主；
- 最终规则是否符合自己的分流目标；
- IP 类规则是否合理使用 `no-resolve`；
- 是否启用了未知脚本、HTTPS 解密或远程规则；
- 配置是否仍有维护来源。

如果现有配置能稳定分流，优先只优化 DNS。未经审查的网络配置可能改变代理范围、证书解密、广告过滤和隐私行为。

## 9. IPv6 是否应该关闭

不能因为检测页面出现 IPv6 就直接关闭。

如果 IPv6 出口也是节点所在地区，说明代理可能已经正确承载 IPv6。此时关闭 IPv6 不一定提高安全，反而可能降低兼容性。

只有确认 IPv6 绕过代理、暴露本地运营商地址时，才把关闭 IPv6 作为单独实验，并在修改后复测。

## 10. iPhone/iPad 是否照抄 Mac

手机配置通常不会自动继承 Mac 上的修改。正确顺序：

1. 手机连接同一节点；
2. 分别在 Wi-Fi 与蜂窝网络下检测；
3. 如果已经只显示预期 DNS，不做任何修改；
4. 如果出现本地运营商 DNS，再按主 DNS、备用 DNS的顺序逐项修改；
5. 每种网络分别复测。

“没有问题就不改”比为了配置统一而重复操作更安全。
