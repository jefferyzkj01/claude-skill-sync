# skill-sync

A Claude Code skill that syncs your skills and plugins across devices using your own private GitHub repo.

## Quickstart

**Just paste this URL into Claude Code and say "安裝這個 skill" (or "install this skill"):**

```
https://github.com/jefferyzkj01/claude-skill-sync
```

Claude will install it automatically. Then tell Claude **"sync my skills"** to begin setup.

---

## How it works across devices

**First device:**
1. Give Claude the URL above → it installs the skill
2. Tell Claude "sync my skills" → guided setup:
   - SSH key check
   - Creates your private `claude-skills` repo on GitHub
   - Pushes all skills + plugin metadata

**New device:**
1. Give Claude the same URL → it installs the skill
2. Tell Claude "sync my skills" → it asks for your private repo SSH URL
3. Detects existing content → restores all skills + prints plugin reinstall commands
4. Run the printed plugin commands → restart Claude Code → done

---

## Manual Install

```bash
mkdir -p ~/.claude/skills/skill-sync/scripts
curl -Lo ~/.claude/skills/skill-sync/SKILL.md \
  https://raw.githubusercontent.com/jefferyzkj01/claude-skill-sync/main/SKILL.md
curl -Lo ~/.claude/skills/skill-sync/scripts/sync.sh \
  https://raw.githubusercontent.com/jefferyzkj01/claude-skill-sync/main/scripts/sync.sh
chmod +x ~/.claude/skills/skill-sync/scripts/sync.sh
```

## First-Time Setup

Run the guided setup:

```bash
bash ~/.claude/skills/skill-sync/scripts/sync.sh init
```

Or just tell Claude: **"sync my skills"** and it will guide you through:
1. SSH key setup
2. Creating your private `claude-skills` repo on GitHub
3. Pushing all your current skills + plugin metadata

## New Device

Once you have a private repo:

```bash
# One command to restore everything:
git clone git@github.com:yourname/claude-skills.git ~/.claude/skills-repo && bash ~/.claude/skills-repo/bootstrap.sh
```

## What it syncs

| Path | What |
|------|------|
| `skills/` | All files in `~/.claude/skills/` |
| `plugins/installed_plugins.json` | Which plugins you have installed |
| `plugins/known_marketplaces.json` | Registered marketplaces |
| `devices.log` | Device registry |

Plugin cache is **not** synced — plugins are re-installed via `claude plugin install`.

## Commands

```bash
SYNC=~/.claude/skills/skill-sync/scripts/sync.sh
bash $SYNC init              # guided first-time setup
bash $SYNC push              # after installing new skills/plugins
bash $SYNC pull              # pull on another device
bash $SYNC status            # check sync state
bash $SYNC devices           # see all registered devices
```

## License

MIT
