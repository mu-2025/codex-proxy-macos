# 排查说明

## 配置了什么

脚本会：

- 设置 `HTTP_PROXY`、`HTTPS_PROXY`、`ALL_PROXY` 及小写形式；
- 创建用户级 LaunchAgent，登录后自动恢复；
- 不修改 App 文件，也不打开 macOS 全局网络代理。

当前已打开的 App 不会自动拿到新变量，配置后要完全退出并重新打开。

## 如何看测试结果

脚本会通过代理访问 ChatGPT 和 OpenAI：

- `401` 或 `403`：请求已到达服务端，代理链路通常正常；
- 超时或拒绝连接：Clash 没启动、端口不对，或没有 HTTP/mixed 端口。

WSS 通常会复用 HTTPS 的 CONNECT 隧道。curl 测试通过后，如果 App 仍然重连，请确认 App 已完全退出，并在重新打开后再试。

## 常见处理

- 端口不对：在代理软件设置中找到 HTTP 或 mixed 端口，再用 `--port` 指定；不要依赖默认端口。
- 没有显式参数时找不到代理：设置 `CODEX_PROXY_URL`，或直接使用 `--proxy URL`。
- 只有 SOCKS 端口：优先在 Clash 开启 HTTP/mixed 端口，不要假设所有 App 都支持 SOCKS 代理变量。
- 变量有值但 App 不通：检查 VPN、网络过滤器或公司代理是否接管了连接。
- 恢复原状：运行 `--uninstall`。替换已有配置前，脚本会保留带时间的备份。
