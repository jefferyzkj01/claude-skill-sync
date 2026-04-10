# skill-sync

A Claude Code skill that syncs your skills and plugins across devices using your own private GitHub repo.

## Install

```bash
# As a Claude Code plugin (recommended):
/plugin marketplace add jefferyzkj01/skill-sync
/plugin install skill-sync@skill-sync --scope user
```

Or manually:
```bash
mkdir -p ~/.claude/skills/skill-sync/scripts
curl -Lo ~/.claude/skills/skill-sync/SKILL.md \
  https://raw.githubusercontent.com/jefferyzkj01/skill-sync/main/SKILL.md
curl -Lo ~/.claude/skills/skill-sync/scripts/sync.sh \
  https://raw.githubusercontent.com/jefferyzkj01/skill-sync/main/scripts/sync.sh
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
