---
name: skill-sync
description: Sync Claude Code skills AND plugins across devices using a private GitHub repo. Use this skill whenever the user wants to sync, backup, restore, push, or pull their Claude skills or plugins across multiple machines or devices. Triggers include: "sync my skills", "sync plugins", "backup skills to GitHub", "install skills on new device", "skills out of date", "push skills", "pull skills", "衝突", or any mention of cross-device skill or plugin management. Always use this skill when the user mentions skill synchronization even casually.
---

# Skill Sync

Synchronizes `~/.claude/skills/` and plugin metadata to a private GitHub repo via SSH.
Plugin cache is NOT synced (too large) — plugins are re-installed from metadata on new devices.

## What gets synced

```
Your private GitHub repo/
├── skills/          ← ~/.claude/skills/ (full copy)
├── plugins/
│   ├── installed_plugins.json    ← which plugins are installed + versions
│   └── known_marketplaces.json   ← registered marketplaces
└── devices.log      ← device registry
```

---

## Script location

```
~/.claude/skills/skill-sync/scripts/sync.sh
```

---

## Commands

| Command | What it does |
|---------|-------------|
| `init <repo_url>` | First-time setup: connect to your private repo (or create one) |
| `push` | Commit and push skills + plugin metadata to GitHub |
| `pull` | Pull from GitHub, restore skills + print plugin reinstall commands |
| `status` | Show local vs remote diff |
| `devices` | List all devices that have synced |

---

## First-Time Setup

### Step 1 — Install this skill (already done if you're reading this)

### Step 2 — Set up SSH key for GitHub

```bash
ssh-keygen -t ed25519 -C "your@email.com"
cat ~/.ssh/id_ed25519.pub   # copy this
# Add to: https://github.com/settings/ssh/new
ssh -T git@github.com       # verify: "Hi yourname!"
```

### Step 3 — Create your private repo

1. Go to https://github.com/new
2. Name: `claude-skills`
3. Visibility: **Private** ← important, this holds your personal config
4. Leave empty (no README)
5. Click **Create repository**
6. Copy the SSH URL: `git@github.com:yourname/claude-skills.git`

### Step 4 — Run init

```bash
bash ~/.claude/skills/skill-sync/scripts/sync.sh init git@github.com:yourname/claude-skills.git
```

This pushes all your current skills and plugin metadata as the first commit.

---

## New Device (already have a private repo)

```bash
# 1. Set up SSH key (same as Step 2 above)

# 2. Clone and bootstrap — one command:
git clone git@github.com:yourname/claude-skills.git ~/.claude/skills-repo && bash ~/.claude/skills-repo/bootstrap.sh

# 3. Run the plugin reinstall commands printed by bootstrap

# 4. Restart Claude Code
```

---

## Day-to-Day

### After installing a new skill or plugin
```bash
bash ~/.claude/skills/skill-sync/scripts/sync.sh push
```

### Pull on a device that's behind
```bash
bash ~/.claude/skills/skill-sync/scripts/sync.sh pull
```

### Check sync state
```bash
bash ~/.claude/skills/skill-sync/scripts/sync.sh status
```

---

## Plugin Restore (new device)

After `pull` or `bootstrap`, the script reads `plugins/installed_plugins.json`
and prints exact commands to reinstall everything. Example:

```
To restore plugins, run:
  claude plugin marketplace add obra/superpowers-marketplace
  claude plugin install superpowers@superpowers-marketplace --scope user
  claude plugin marketplace add anthropics/skills
  claude plugin install example-skills@anthropic-agent-skills --scope user
```

---

## Conflict Handling

When `pull` detects both local and remote changed the same skill:

```
Conflicts detected:
  ≠ skills/my-skill/SKILL.md

Options:
  1) Remote wins (overwrite local)
  2) Local wins (keep local)
  3) Abort — let me decide manually
```

---

## How Claude Should Help

| User says | Action |
|-----------|--------|
| 「第一次設定」/ "first time setup" | Walk through Steps 2-4 above |
| 「同步我的 skills」/ "sync" | Run `push` |
| 「新裝置」/ "new device" | Show the one-command bootstrap |
| 「拉下來」/ "pull" | Run `pull` |
| 「有衝突」/ "conflict" | Explain options, show diff command |
| 「查狀態」/ "status" | Run `status` |
| 「有哪些裝置」/ "devices" | Run `devices` |

**First-time detection:** If `~/.claude/skills-repo` does not exist, proactively
walk the user through creating a private repo and running `init`.

Always confirm SSH URL is `git@github.com:user/repo.git` (not HTTPS).
