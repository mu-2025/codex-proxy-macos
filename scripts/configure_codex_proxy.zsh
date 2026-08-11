#!/bin/zsh
set -euo pipefail

typeset skill_label="com.codex.proxy-env"
typeset -a candidate_ports=(7897 7890 7891 7892 7893 9090)
typeset action="install"
typeset proxy_url=""
typeset explicit_port=""
typeset dry_run=0
typeset skip_network_test=0

usage() {
  print -r -- "Usage: configure_codex_proxy.zsh [--proxy URL | --port PORT] [--check | --uninstall] [--dry-run] [--skip-network-test]"
}

user_home_dir() {
  [[ -n "${HOME:-}" ]] && { print -r -- "$HOME"; return; }
  local detected=""
  detected="$(/usr/bin/dscl . -read "/Users/$(/usr/bin/id -un)" NFSHomeDirectory 2>/dev/null \
    | /usr/bin/sed 's/^NFSHomeDirectory: //' || true)"
  [[ -n "$detected" ]] && { print -r -- "$detected"; return; }
  return 1
}

escape_xml() {
  local value="$1"
  value="${value//&/&amp;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  value="${value//\"/&quot;}"
  value="${value//\'/&apos;}"
  print -r -- "$value"
}

proxy_is_valid() {
  [[ "$1" == (http|https|socks5|socks5h)://* ]] || {
    print -u2 -- "Invalid proxy URL: $1 (expected http://, https://, socks5://, or socks5h://)"
    return 1
  }
}

listener_exists() {
  local port="$1"
  /usr/sbin/lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null | /usr/bin/grep -q LISTEN
}

detect_proxy() {
  if [[ -n "$proxy_url" ]]; then
    proxy_is_valid "$proxy_url"
    return
  fi
  if [[ -n "$explicit_port" ]]; then
    [[ "$explicit_port" == <-> ]] || { print -u2 -- "Invalid port: $explicit_port"; return 1; }
    listener_exists "$explicit_port" || print -u2 -- "Warning: no local listener detected on port $explicit_port; continuing because it was explicit."
    proxy_url="http://127.0.0.1:$explicit_port"
    return
  fi
  local existing
  existing="$(/bin/launchctl getenv HTTPS_PROXY 2>/dev/null || true)"
  if [[ -n "$existing" && "$existing" == (http|https|socks5|socks5h)://127.0.0.1:* ]]; then
    proxy_url="$existing"
    return
  fi
  local port
  for port in $candidate_ports; do
    if listener_exists "$port"; then
      proxy_url="http://127.0.0.1:$port"
      return
    fi
  done
  print -u2 -- "No Clash HTTP/mixed listener found. Re-run with --proxy URL or --port PORT."
  return 1
}

state_dir_for() { print -r -- "$1/Library/Application Support/CodexProxy"; }
state_file_for() { print -r -- "$(state_dir_for "$1")/proxy-url"; }
plist_for() { print -r -- "$1/Library/LaunchAgents/$skill_label.plist"; }

set_session_proxy() {
  local name
  for name in HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy; do
    /bin/launchctl setenv "$name" "$proxy_url"
  done
  for name in NO_PROXY no_proxy; do
    /bin/launchctl setenv "$name" "127.0.0.1,localhost,::1"
  done
}

make_plist() {
  local output="$1" command quoted_proxy escaped_command
  # zsh parameter quoting is portable on macOS; BSD printf does not implement %q.
  quoted_proxy="${(q)proxy_url}"
  command="proxy_url=$quoted_proxy; for name in HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy; do /bin/launchctl setenv \"\$name\" \"\$proxy_url\"; done; for name in NO_PROXY no_proxy; do /bin/launchctl setenv \"\$name\" \"127.0.0.1,localhost,::1\"; done"
  escaped_command="$(escape_xml "$command")"
  {
    print -r -- '<?xml version="1.0" encoding="UTF-8"?>'
    print -r -- '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
    print -r -- '<plist version="1.0"><dict>'
    print -r -- "<key>Label</key><string>$skill_label</string>"
    print -r -- '<key>ProgramArguments</key><array><string>/bin/zsh</string><string>-c</string>'
    print -r -- "<string>$escaped_command</string></array>"
    print -r -- '<key>RunAtLoad</key><true/>'
    print -r -- '</dict></plist>'
  } >| "$output"
}

network_test() {
  local code
  code="$(/usr/bin/curl -sS -o /dev/null -w '%{http_code}' --proxy "$proxy_url" --connect-timeout 5 --max-time 15 https://api.openai.com/v1/models 2>/dev/null)" || {
    print -u2 -- "OpenAI HTTPS test failed through $proxy_url"
    return 1
  }
  print -r -- "OpenAI HTTPS via proxy: HTTP $code (401/403 means the tunnel reached the service)"
  code="$(/usr/bin/curl -sS -o /dev/null -w '%{http_code}' --proxy "$proxy_url" --connect-timeout 5 --max-time 15 https://chatgpt.com/ 2>/dev/null)" || {
    print -u2 -- "ChatGPT HTTPS test failed through $proxy_url"
    return 1
  }
  print -r -- "ChatGPT HTTPS via proxy: HTTP $code"
}

check() {
  local home="$1" plist_path="$(plist_for "$1")" name value
  print -r -- "LaunchAgent: $plist_path"
  [[ -f "$plist_path" ]] && print -r -- "LaunchAgent file: present" || print -r -- "LaunchAgent file: absent"
  for name in HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy; do
    value="$(/bin/launchctl getenv "$name" 2>/dev/null || true)"
    print -r -- "$name=${value:-<unset>}"
  done
  if [[ -f "$plist_path" ]]; then
    /bin/launchctl print "gui/$UID/$skill_label" 2>/dev/null | /usr/bin/grep -E 'state =|runs =|last exit code' || true
  fi
}

uninstall() {
  local home="$1" plist_path="$(plist_for "$1")" state_file="$(state_file_for "$1")"
  local stored_proxy="" name value
  [[ -f "$state_file" ]] && stored_proxy="$(/bin/cat "$state_file")"
  /bin/launchctl bootout "gui/$UID" "$plist_path" 2>/dev/null || true
  if [[ -n "$stored_proxy" ]]; then
    for name in HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy; do
      value="$(/bin/launchctl getenv "$name" 2>/dev/null || true)"
      [[ "$value" == "$stored_proxy" ]] && /bin/launchctl unsetenv "$name"
    done
  fi
  [[ -f "$plist_path" ]] && /bin/rm "$plist_path"
  [[ -f "$state_file" ]] && /bin/rm "$state_file"
  print -r -- "Removed $skill_label LaunchAgent and its owned proxy environment (if still unchanged)."
}

while (( $# > 0 )); do
  case "$1" in
    --proxy) (( $# >= 2 )) || { usage; exit 2; }; proxy_url="$2"; shift 2 ;;
    --port) (( $# >= 2 )) || { usage; exit 2; }; explicit_port="$2"; shift 2 ;;
    --check) action="check"; shift ;;
    --uninstall) action="uninstall"; shift ;;
    --dry-run) dry_run=1; shift ;;
    --skip-network-test) skip_network_test=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) print -u2 -- "Unknown argument: $1"; usage; exit 2 ;;
  esac
done

[[ "$(/usr/bin/uname -s)" == "Darwin" ]] || { print -u2 -- "This skill requires macOS."; exit 1; }
typeset user_home="$(user_home_dir)"
typeset plist_path="$(plist_for "$user_home")"

if [[ "$action" == "check" ]]; then
  check "$user_home"
  exit 0
fi
if [[ "$action" == "uninstall" ]]; then
  uninstall "$user_home"
  exit 0
fi

detect_proxy
print -r -- "Using proxy: $proxy_url"
if (( dry_run )); then
  print -r -- "Dry run: would set GUI proxy variables and install $plist_path"
  exit 0
fi
if (( ! skip_network_test )); then
  network_test
fi

typeset launch_agents_dir="$user_home/Library/LaunchAgents"
/bin/mkdir -p "$launch_agents_dir"
if [[ -f "$plist_path" ]]; then
  /bin/cp "$plist_path" "$plist_path.bak.$(/bin/date +%Y%m%d%H%M%S)"
fi
make_plist "$plist_path"
set_session_proxy
/bin/launchctl bootout "gui/$UID" "$plist_path" 2>/dev/null || true
/bin/launchctl bootstrap "gui/$UID" "$plist_path"
/bin/launchctl kickstart -k "gui/$UID/$skill_label" 2>/dev/null || true

typeset state_dir="$(state_dir_for "$user_home")"
/bin/mkdir -p "$state_dir"
print -r -- "$proxy_url" >| "$(state_file_for "$user_home")"
print -r -- "Installed $skill_label and loaded it into GUI session $UID."
check "$user_home"
