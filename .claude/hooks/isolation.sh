#!/usr/bin/env bash

exec python3 -I -c '
import glob, json, os, platform, sys

root = sys.argv[1]
try:
    data = json.loads(sys.stdin.read())
except ValueError:
    data = None
event = data.get("hook_event_name") if isinstance(data, dict) else None
event = event if event in ("SessionStart", "UserPromptSubmit") else "SessionStart"


def isolation():
    user = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")
    files = ["/etc/claude-code/managed-settings.json", "/Library/Application Support/ClaudeCode/managed-settings.json"]
    files += sorted(glob.glob("/etc/claude-code/managed-settings.d/*.json"))
    files += sorted(glob.glob("/Library/Application Support/ClaudeCode/managed-settings.d/*.json"))
    files += [os.path.join(root, ".claude", "settings.local.json"), os.path.join(root, ".claude", "settings.json"),
              os.path.join(user, "settings.json")]
    settings = []
    for path in files:
        try:
            with open(path) as f:
                data = json.load(f)
        except (OSError, ValueError):
            continue
        if isinstance(data, dict):
            settings.append(data)
    envs = [s.get("env") for s in settings if isinstance(s.get("env"), dict)]
    boxes = [s.get("sandbox") for s in settings if isinstance(s.get("sandbox"), dict)]
    forged = any(k.startswith("CLAUDE_CODE_REMOTE") for e in envs for k in e)
    if os.environ.get("CLAUDE_CODE_REMOTE") == "true" and os.environ.get("CLAUDE_CODE_REMOTE_ENVIRONMENT_TYPE", "").startswith("cloud") and not forged:
        where = "a cloud container"
    else:
        enabled = [b["enabled"] for b in boxes if "enabled" in b]
        strict = [b["failIfUnavailable"] for b in boxes if "failIfUnavailable" in b]
        open_fs = any((b.get("filesystem") or {}).get("disabled") is True for b in boxes if isinstance(b.get("filesystem"), dict))
        home = os.path.realpath(os.path.expanduser("~"))
        wide = [os.path.expanduser(str(d)) for s in settings for d in (s.get("permissions") or {}).get("additionalDirectories") or []]
        wide += [os.path.expanduser(str(d)) for b in boxes for d in (b.get("filesystem") or {}).get("allowWrite") or []]
        reaches = any(os.path.realpath(d) in (home, "/") or os.path.join(home, ".claude").startswith(os.path.realpath(d) + os.sep) for d in wide)
        weak = any(b.get("enableWeakerNestedSandbox") is True or (b.get("network") or {}).get("allowUnixSockets") for b in boxes)
        flags = b""
        pid = os.getppid()
        for _ in range(6):
            try:
                with open("/proc/%d/cmdline" % pid, "rb") as f:
                    flags += f.read() + b"\0"
                with open("/proc/%d/stat" % pid) as f:
                    pid = int(f.read().rsplit(")", 1)[1].split()[1])
            except (OSError, ValueError, IndexError):
                break
        cli = not flags or any(x in flags for x in (b"--settings", b"--setting-sources", b"--add-dir", b"--permission-mode", b"--dangerously-skip-permissions"))
        on = enabled and all(e is True for e in enabled) and strict and all(s is True for s in strict) and not open_fs \
            and platform.system() != "Windows" and not reaches and not weak and not cli
        if on:
            out = sorted({c for b in boxes for c in b.get("excludedCommands") or [] if isinstance(c, str)})
            where = "this machine, with the Bash sandbox on" + ("; these run outside it: " + ", ".join(out) if out else "")
        else:
            where = "this machine, with no sandbox"
    return where


try:
    where = isolation()
except Exception:
    where = "this machine, with no sandbox"
print(json.dumps({"hookSpecificOutput": {"hookEventName": event, "additionalContext": "Stewie isolation: " + where + "."}}))
' "${CLAUDE_PROJECT_DIR:-$(pwd)}"
