# macOS Codex 代理 Skill

为 Codex / ChatGPT macOS 桌面 App 配置持久化 Clash 代理，解决新建会话反复重连、HTTP 请求正常但 WebSocket/WSS 连接失败的问题。

本仓库就是一个 Codex Skill，不修改 App 文件，也不需要 zip。

## 安装

在 Mac 上运行：

```bash
python3 ~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py \
  --repo mu-2025/codex-proxy-macos \
  --path . \
  --name codex-proxy-macos
```

安装后在 Codex 中调用：

```text
$codex-proxy-macos
```

例如：

> 检查 Clash 的 HTTP/mixed 端口，为 Codex 配置持久化代理并验证连接。

如果没有 Skill 安装器，也可以直接克隆：

```bash
git clone git@github.com:mu-2025/codex-proxy-macos.git /tmp/codex-proxy-macos
mkdir -p ~/.codex/skills
cp -R /tmp/codex-proxy-macos/. ~/.codex/skills/codex-proxy-macos/
```

## 直接运行

先查看状态：

```zsh
zsh ~/.codex/skills/codex-proxy-macos/scripts/configure_codex_proxy.zsh --check
```

本机 HTTP/mixed 端口由代理软件决定，配置时显式填写：

```zsh
read -r "PROXY_PORT?请输入代理软件的 HTTP/mixed 端口: "
zsh ~/.codex/skills/codex-proxy-macos/scripts/configure_codex_proxy.zsh --port "$PROXY_PORT"
```

如果使用其他地址或 SOCKS 代理，传入完整 URL：

```zsh
read -r "PROXY_URL?请输入代理 URL: "
zsh ~/.codex/skills/codex-proxy-macos/scripts/configure_codex_proxy.zsh --proxy "$PROXY_URL"
```

省略参数时，脚本只读取已有代理环境或 macOS 系统代理，不会猜测端口。

预览和卸载：

```zsh
zsh ~/.codex/skills/codex-proxy-macos/scripts/configure_codex_proxy.zsh --dry-run --proxy "$PROXY_URL"
zsh ~/.codex/skills/codex-proxy-macos/scripts/configure_codex_proxy.zsh --uninstall
```

## 工作方式

脚本会在当前用户的 GUI 会话设置 `HTTP_PROXY`、`HTTPS_PROXY`、`ALL_PROXY` 及小写形式，并创建用户级 LaunchAgent，在登录时自动恢复。它不修改 Codex/ChatGPT App，因此 App 更新不会覆盖配置。

完成后请完全退出并重新打开 Codex（`⌘Q`）。`401` 或 `403` 通常表示请求已经通过代理到达服务端；超时或拒绝连接才表示代理链路失败。

详细排查见 [references/troubleshooting.md](references/troubleshooting.md)。
