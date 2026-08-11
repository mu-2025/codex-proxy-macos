# macOS Codex 代理 Skill

为 Codex / ChatGPT macOS App 配置持久化代理，解决新会话反复重连或 WSS 连接失败。

## 推荐：让 Agent 直接处理

在 Codex 新建对话，发送：

```text
请使用 https://github.com/mu-2025/codex-proxy-macos 中的 codex-proxy-macos Skill，解决 Codex 新建会话反复重连问题。
请检查本机代理环境；如果缺少代理 URL 或端口，再向我询问。请由你完成安装、配置和验证，不要让我手动执行脚本。
```

## 手动安装

```bash
python3 ~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py \
  --repo mu-2025/codex-proxy-macos --path . --name codex-proxy-macos
```

安装后调用：

```text
$codex-proxy-macos
```

## 手动配置（可选）

```zsh
SCRIPT=~/.codex/skills/codex-proxy-macos/scripts/configure_codex_proxy.zsh

# 查看状态
zsh "$SCRIPT" --check

# 指定本机 HTTP/mixed 端口
read -r "PROXY_PORT?请输入端口: "
zsh "$SCRIPT" --port "$PROXY_PORT"

# 指定完整代理 URL（HTTP/HTTPS/SOCKS）
read -r "PROXY_URL?请输入代理 URL: "
zsh "$SCRIPT" --proxy "$PROXY_URL"

# 卸载
zsh "$SCRIPT" --uninstall
```

端口或 URL 由本机代理软件决定；不传参数时，脚本只读取已有代理环境或 macOS 系统代理，不会猜测端口。

配置后完全退出并重新打开 Codex。测试返回 `401`/`403` 通常表示代理链路已连通；超时或拒绝连接才表示失败。

详细排查见 [references/troubleshooting.md](references/troubleshooting.md)。
