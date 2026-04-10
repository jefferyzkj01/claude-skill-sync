---
name: skill-sync
description: Sync Claude Code skills AND plugins across devices using a private GitHub repo. Use this skill whenever the user wants to sync, backup, restore, push, or pull their Claude skills or plugins across multiple machines or devices. Triggers include: "sync my skills", "sync plugins", "backup skills to GitHub", "install skills on new device", "skills out of date", "push skills", "pull skills", "衝突", or any mention of cross-device skill or plugin management. Always use this skill when the user mentions skill synchronization even casually.
---

# Skill Sync

Syncs `~/.claude/skills/` and plugin metadata to the user's private GitHub repo.
**Claude handles all operations directly — the user never needs to open a terminal.**

## What gets synced

```
User's private GitHub repo/
├── skills/          ← ~/.claude/skills/
├── plugins/
│   ├── installed_plugins.json
│   └── known_marketplaces.json
├── bootstrap.sh     ← new device restore script
└── devices.log
```

---

## How Claude Should Operate

**Always use Bash tool to execute operations directly.** Never tell the user to run commands themselves. Do it for them in the conversation.

---

## Workflow 1 — First Time Setup (no private repo yet)

Detect: `~/.claude/skills-repo/.git` does not exist AND no `~/.claude/skill-sync.conf`

```
1. Tell user what skill-sync does (one short paragraph)

2. Check SSH:
   Run: ssh -T git@github.com 2>&1 || true
   - If authenticated → proceed
   - If not → run: ssh-keygen -t ed25519 -C "claude-skill-sync" -f ~/.ssh/id_ed25519 -N ""
     Then show public key: cat ~/.ssh/id_ed25519.pub
     Ask user to add it at https://github.com/settings/ssh/new
     Wait for user confirmation, then verify: ssh -T git@github.com 2>&1 || true

3. Ask user to create a private GitHub repo:
   "Please go to https://github.com/new, name it 'claude-skills', set to Private, leave empty, then paste me the SSH URL (git@github.com:yourname/claude-skills.git)"

4. Clone and push:
   git clone <url> ~/.claude/skills-repo
   cp -r ~/.claude/skills/. ~/.claude/skills-repo/skills/
   mkdir -p ~/.claude/skills-repo/plugins
   cp ~/.claude/plugins/installed_plugins.json ~/.claude/skills-repo/plugins/ 2>/dev/null || true
   cp ~/.claude/plugins/known_marketplaces.json ~/.claude/skills-repo/plugins/ 2>/dev/null || true
   Write bootstrap.sh (see Bootstrap Script section below)
   Update devices.log
   cd ~/.claude/skills-repo && git add -A && git commit -m "init: first sync from $(hostname)" && git push

5. Save config: echo "SKILL_SYNC_REPO=<url>" > ~/.claude/skill-sync.conf

6. Tell user: "Done! Your skills are backed up. On a new device, just install this skill and tell me 'sync my skills'."
```

---

## Workflow 2 — Push (existing repo, push local changes)

Detect: `~/.claude/skills-repo/.git` exists

```
1. cd ~/.claude/skills-repo && git fetch origin
2. Check if behind remote → warn user if so
3. cp -r ~/.claude/skills/. ~/.claude/skills-repo/skills/
4. cp ~/.claude/plugins/installed_plugins.json ~/.claude/skills-repo/plugins/ 2>/dev/null || true
5. cp ~/.claude/plugins/known_marketplaces.json ~/.claude/skills-repo/plugins/ 2>/dev/null || true
6. Update devices.log
7. git add -A
8. Show what changed (git diff --staged --name-only)
9. git commit -m "sync: push from $(hostname) at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
10. git push
11. Report: "Pushed N files to GitHub."
```

---

## Workflow 3 — Pull / New Device (repo exists remotely, not locally)

Detect: `~/.claude/skills-repo/.git` does not exist but user provides a repo URL

```
1. Check SSH (same as Workflow 1 step 2)
2. Ask for private repo SSH URL if not known
3. git clone <url> ~/.claude/skills-repo
4. cp -r ~/.claude/skills-repo/skills/. ~/.claude/skills/
5. cp ~/.claude/skills-repo/plugins/installed_plugins.json ~/.claude/plugins/ 2>/dev/null || true
6. cp ~/.claude/skills-repo/plugins/known_marketplaces.json ~/.claude/plugins/ 2>/dev/null || true
7. Update devices.log and push
8. Read installed_plugins.json and run each plugin install:
   - For each marketplace in known_marketplaces.json: claude plugin marketplace add <repo>
   - For each plugin in installed_plugins.json: claude plugin install <key> --scope <scope>
9. Save ~/.claude/skill-sync.conf
10. Tell user: "All skills restored and plugins reinstalled. Please restart Claude Code."
```

---

## Workflow 4 — Status

```
1. cd ~/.claude/skills-repo && git fetch origin --quiet
2. cp -r ~/.claude/skills/. ~/.claude/skills-repo/skills/ (staging only)
3. git diff --name-only → show modified
4. git ls-files --others --exclude-standard → show local-only
5. git diff HEAD..origin/main --name-only → show remote-newer
6. git checkout -- . (restore repo to committed state)
7. Show summary table
```

---

## Devices Log Format

```
HOSTNAME\tOS\tTIMESTAMP
```

Update before every commit:
```bash
log=~/.claude/skills-repo/devices.log
device=$(hostname)
ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
os=$(uname -s)
touch "$log"
grep -v "^${device}	" "$log" > "${log}.tmp" 2>/dev/null || true
printf "%s\t%s\t%s\n" "$device" "$os" "$ts" >> "${log}.tmp"
mv "${log}.tmp" "$log"
```

---

## Bootstrap Script

Write this to `~/.claude/skills-repo/bootstrap.sh` during first init.
This lets new devices restore with one command even before Claude is set up:

```bash
#!/usr/bin/env bash
# bootstrap.sh — restore Claude skills on a new device
# Usage: git clone git@github.com:you/claude-skills.git ~/.claude/skills-repo && bash ~/.claude/skills-repo/bootstrap.sh
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p ~/.claude/skills ~/.claude/plugins
[[ -d "$REPO/skills" ]] && cp -r "$REPO/skills"/. ~/.claude/skills/
for f in installed_plugins.json known_marketplaces.json; do
  [[ -f "$REPO/plugins/$f" ]] && cp "$REPO/plugins/$f" ~/.claude/plugins/
done
echo "Skills restored. Now tell Claude Code: 'sync my skills' to reinstall plugins."
```

---

## Config File

`~/.claude/skill-sync.conf` stores the private repo URL:
```
SKILL_SYNC_REPO=git@github.com:user/claude-skills.git
```

Read at start of each workflow to skip asking for URL again.

---

## How Claude Should Respond

| User says | Action |
|-----------|--------|
| 「第一次」/ "first time" / no repo found | Workflow 1 |
| 「同步」/ "sync" / "push" | Workflow 2 if repo exists, else Workflow 1 |
| 「新裝置」/ "new device" / "pull" | Workflow 3 |
| 「查狀態」/ "status" | Workflow 4 |
| 「有哪些裝置」/ "devices" | Read and display devices.log |

**Key principle: Claude does the work. The user just answers questions.**
