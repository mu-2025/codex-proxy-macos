---
name: codex-proxy-macos
description: 在 macOS 上为 Codex 或 ChatGPT 桌面 App 配置持久化 Clash 代理，解决新会话反复重连、HTTP 能通但 WebSocket/WSS 失败等问题。适用于 Clash 使用代理模式而非 TUN 模式的情况。
---

# macOS Codex 代理

用脚本检查本机 Clash 端口，并通过用户级 LaunchAgent 持久化代理环境。不修改 App 文件，所以 App 更新后仍然有效。

## 使用流程

1. 先运行 `--check` 查看当前状态。只诊断时不要执行安装。
2. 运行脚本安装配置。代理软件和端口由本机决定，优先显式指定：

   ```zsh
   zsh scripts/configure_codex_proxy.zsh --port <Clash 的 HTTP/mixed 端口>
   ```

   也可以直接传 URL：

   ```zsh
   zsh scripts/configure_codex_proxy.zsh --proxy http://127.0.0.1:<端口>
   ```

   `--port` 适用于本机 HTTP/mixed 端口；其他地址或 SOCKS 代理使用 `--proxy URL`。如果省略参数，脚本只会读取已有代理环境或 macOS 系统代理，不会猜测端口。
3. 配置完成后完全退出并重新打开 Codex（`⌘Q`），让新进程继承代理环境。
4. 卸载：

   ```zsh
   zsh scripts/configure_codex_proxy.zsh --uninstall
   ```

## 脚本选项

- `--check`：只查看 LaunchAgent 和代理变量。
- `--dry-run`：只检测并预览，不修改系统。
- `--skip-network-test`：跳过联网验证，网络恢复后再验证。
- `--uninstall`：删除本 Skill 创建的配置。

也可以先设置 `CODEX_PROXY_URL`，再运行脚本；命令行参数优先级更高。

## 注意事项

- 优先使用 Clash 的 HTTP 或 mixed 端口。HTTPS 代理通过 CONNECT 建立，WSS 通常会复用这条隧道。
- `401` 或 `403` 说明请求已经到达服务端，通常表示代理链路正常；超时或拒绝连接才是链路失败。
- 配置只作用于读取代理环境变量的应用，不会改动 macOS 全局网络代理。
- 详细排查见 [references/troubleshooting.md](references/troubleshooting.md)。
