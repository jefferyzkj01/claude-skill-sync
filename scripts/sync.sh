#!/usr/bin/env bash
# skill-sync/scripts/sync.sh
# Sync ~/.claude/skills/ + plugin metadata with a private GitHub repo via SSH.
#
# Usage:
#   ./sync.sh init <git@github.com:user/claude-skills.git>
#   ./sync.sh push        (guided setup if first time)
#   ./sync.sh pull
#   ./sync.sh status
#   ./sync.sh devices

set -euo pipefail

SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
PLUGINS_DIR="$HOME/.claude/plugins"
REPO_DIR="$HOME/.claude/skills-repo"
CONFIG_FILE="$HOME/.claude/skill-sync.conf"
DEVICE="$(hostname)"
OS="$(uname -s)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${BLUE}[info]${NC}  $*"; }
success() { echo -e "${GREEN}[ok]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC}  $*"; }
error()   { echo -e "${RED}[error]${NC} $*" >&2; exit 1; }

check_deps() {
  command -v git &>/dev/null || error "git is required but not installed."
}

check_ssh() {
  local result
  result=$(ssh -T git@github.com 2>&1 || true)
  if ! echo "$result" | grep -q "successfully authenticated"; then
    warn "SSH key not set up for GitHub."
    echo ""
    echo "Run these commands:"
    echo "  ssh-keygen -t ed25519 -C \"your@email.com\""
    echo "  cat ~/.ssh/id_ed25519.pub   # add to https://github.com/settings/ssh/new"
    echo "  ssh -T git@github.com       # verify"
    echo ""
    error "Set up SSH key first, then re-run."
  fi
}

save_repo_url() { echo "SKILL_SYNC_REPO=$1" > "$CONFIG_FILE"; }
load_repo_url() {
  [[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE" || true
  echo "${SKILL_SYNC_REPO:-}"
}

# ── New user onboarding ───────────────────────────────────────────────────────
onboard_new_user() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║       skill-sync — First Time Setup      ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
  echo ""
  echo "This will back up your Claude skills & plugins to a private"
  echo "GitHub repo so you can restore them on any device."
  echo ""

  echo -e "${YELLOW}Step 1 — Checking SSH key for GitHub...${NC}"
  local ssh_result
  ssh_result=$(ssh -T git@github.com 2>&1 || true)
  if echo "$ssh_result" | grep -q "successfully authenticated"; then
    success "SSH key already configured."
  else
    echo ""
    echo "SSH key not found. Run these commands first:"
    echo "  ssh-keygen -t ed25519 -C \"your@email.com\""
    echo "  cat ~/.ssh/id_ed25519.pub"
    echo "  # Add to: https://github.com/settings/ssh/new"
    echo "  ssh -T git@github.com   # should say 'Hi yourname!'"
    echo ""
    echo "Once done, run again: bash ~/.claude/skills/skill-sync/scripts/sync.sh init"
    exit 0
  fi

  echo ""
  echo -e "${YELLOW}Step 2 — Create your private GitHub repo${NC}"
  echo ""
  echo "  1. Open: https://github.com/new"
  echo "  2. Name it: claude-skills"
  echo "  3. Set to: Private"
  echo "  4. Leave empty (no README)"
  echo "  5. Click 'Create repository'"
  echo ""
  printf "Paste your SSH repo URL (git@github.com:yourname/claude-skills.git): "
  read -r repo_url

  [[ -z "$repo_url" ]] && error "No URL provided. Aborting."

  if ! echo "$repo_url" | grep -q "^git@github.com:"; then
    warn "Expected format: git@github.com:user/repo.git"
    printf "Continue anyway? (y/N): "
    read -r ans; [[ "$ans" =~ ^[Yy]$ ]] || { info "Aborted."; exit 0; }
  fi

  cmd_init "$repo_url"
}

# ── File helpers ──────────────────────────────────────────────────────────────
skills_to_repo() {
  mkdir -p "$REPO_DIR/skills"
  cp -r "$SKILLS_DIR"/. "$REPO_DIR/skills/"
}

repo_to_skills() {
  mkdir -p "$SKILLS_DIR"
  cp -r "$REPO_DIR/skills"/. "$SKILLS_DIR/"
}

plugins_meta_to_repo() {
  mkdir -p "$REPO_DIR/plugins"
  for f in installed_plugins.json known_marketplaces.json; do
    [[ -f "$PLUGINS_DIR/$f" ]] && cp "$PLUGINS_DIR/$f" "$REPO_DIR/plugins/$f"
  done
}

repo_to_plugins_meta() {
  mkdir -p "$PLUGINS_DIR"
  for f in installed_plugins.json known_marketplaces.json; do
    [[ -f "$REPO_DIR/plugins/$f" ]] && cp "$REPO_DIR/plugins/$f" "$PLUGINS_DIR/$f"
  done
}

print_plugin_restore_commands() {
  local json="$REPO_DIR/plugins/installed_plugins.json"
  local mkt_json="$REPO_DIR/plugins/known_marketplaces.json"
  [[ -f "$json" ]] || return 0

  echo ""
  echo -e "${CYAN}=== To restore plugins, run: ===${NC}"

  if command -v python3 &>/dev/null && [[ -f "$mkt_json" ]]; then
    python3 - <<PYEOF
import json
with open('$mkt_json') as f:
    mkt = json.load(f)
with open('$json') as f:
    plg = json.load(f)
for name, info in mkt.items():
    src = info.get('source', {})
    if src.get('source') == 'github':
        print(f"  claude plugin marketplace add {src['repo']}")
print()
for plugin_key, installs in plg.get('plugins', {}).items():
    for install in installs:
        scope = install.get('scope', 'user')
        print(f"  claude plugin install {plugin_key} --scope {scope}")
PYEOF
  else
    echo "  (python3 not found — check plugins/installed_plugins.json manually)"
  fi
  echo ""
}

update_device_log() {
  local log="$REPO_DIR/devices.log"
  local ts; ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  touch "$log"
  grep -v "^${DEVICE}	" "$log" > "${log}.tmp" 2>/dev/null || true
  printf "%s\t%s\t%s\n" "$DEVICE" "$OS" "$ts" >> "${log}.tmp"
  mv "${log}.tmp" "$log"
}

# ── Commands ──────────────────────────────────────────────────────────────────

cmd_init() {
  local repo_url="${1:-}"
  [[ -z "$repo_url" ]] && { onboard_new_user; return; }

  check_ssh

  if [[ -d "$REPO_DIR/.git" ]]; then
    warn "Repo already exists at $REPO_DIR"
    printf "Re-initialize? (y/N): "
    read -r ans; [[ "$ans" =~ ^[Yy]$ ]] || { info "Aborted."; exit 0; }
    rm -rf "$REPO_DIR"
  fi

  info "Cloning $repo_url → $REPO_DIR"
  git clone "$repo_url" "$REPO_DIR"
  save_repo_url "$repo_url"

  if [[ ! -d "$REPO_DIR/skills" ]]; then
    info "New repo — pushing local skills + plugin metadata..."
    skills_to_repo
    plugins_meta_to_repo
    update_device_log

    # Copy bootstrap.sh into the repo
    local this_dir; this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local bootstrap_src="$this_dir/../bootstrap.sh"
    [[ -f "$bootstrap_src" ]] && cp "$bootstrap_src" "$REPO_DIR/bootstrap.sh"

    cd "$REPO_DIR"
    git add -A
    git commit -m "init: first sync from ${DEVICE}"
    git push
    success "Initial push complete."
    echo ""
    echo -e "${GREEN}Done!${NC} Skills backed up to GitHub."
    echo "Future syncs: bash ~/.claude/skills/skill-sync/scripts/sync.sh push"
  else
    info "Existing content — restoring to $SKILLS_DIR ..."
    repo_to_skills
    repo_to_plugins_meta
    update_device_log
    cd "$REPO_DIR"
    git add devices.log
    git commit -m "device: registered ${DEVICE}" 2>/dev/null || true
    git push 2>/dev/null || true
    success "Skills restored from repo."
    print_plugin_restore_commands
  fi

  success "Init complete. Device '${DEVICE}' registered."
}

cmd_push() {
  if [[ ! -d "$REPO_DIR/.git" ]]; then
    local saved_url; saved_url=$(load_repo_url)
    if [[ -n "$saved_url" ]]; then
      cmd_init "$saved_url"; return
    fi
    onboard_new_user; return
  fi

  check_ssh
  cd "$REPO_DIR"
  info "Fetching latest from GitHub..."
  git fetch origin

  local branch; branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "main")
  local behind; behind=$(git rev-list HEAD..origin/"$branch" --count 2>/dev/null || echo 0)

  if (( behind > 0 )); then
    warn "Remote has $behind commit(s) ahead. Run 'sync.sh pull' first."
    printf "Force push anyway? (y/N): "
    read -r ans; [[ "$ans" =~ ^[Yy]$ ]] || { info "Aborted."; exit 0; }
  fi

  skills_to_repo
  plugins_meta_to_repo
  update_device_log

  if git diff --quiet && git diff --staged --quiet; then
    local untracked; untracked=$(git ls-files --others --exclude-standard | wc -l | tr -d ' ')
    (( untracked == 0 )) && { success "Nothing to push. Already up to date."; exit 0; }
  fi

  git add -A
  local changed; changed=$(git diff --staged --name-only | wc -l | tr -d ' ')

  echo ""
  echo "Changes to push ($changed files):"
  git diff --staged --name-only | sed 's/^/  /'
  echo ""
  printf "Confirm push? (Y/n): "
  read -r ans
  [[ "$ans" =~ ^[Nn]$ ]] && { info "Aborted."; exit 0; }

  git commit -m "sync: push from ${DEVICE} at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  git push
  success "Push complete. $changed file(s) synced."
}

cmd_pull() {
  [[ -d "$REPO_DIR/.git" ]] || error "Not initialized. Run: sync.sh init"
  check_ssh
  cd "$REPO_DIR"
  git fetch origin

  local branch; branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "main")
  local incoming; incoming=$(git diff HEAD..origin/"$branch" --name-only 2>/dev/null | wc -l | tr -d ' ')

  if (( incoming == 0 )); then success "Already up to date."; exit 0; fi

  echo ""
  echo "Incoming changes ($incoming files):"
  git diff HEAD..origin/"$branch" --name-only | sed 's/^/  /'
  echo ""

  local conflicts=()
  while IFS= read -r file; do
    local local_path="${SKILLS_DIR}/${file#skills/}"
    if [[ -e "$local_path" ]]; then
      local repo_hash; repo_hash=$(git show origin/"$branch":"$file" 2>/dev/null | md5sum | awk '{print $1}' || echo "")
      local local_hash; local_hash=$(md5sum "$REPO_DIR/$file" 2>/dev/null | awk '{print $1}' || echo "")
      [[ "$repo_hash" != "$local_hash" ]] && conflicts+=("$file")
    fi
  done < <(git diff HEAD..origin/"$branch" --name-only 2>/dev/null | grep '^skills/' || true)

  if (( ${#conflicts[@]} > 0 )); then
    echo -e "${YELLOW}Conflicts:${NC}"
    for f in "${conflicts[@]}"; do echo "  ≠ $f"; done
    echo "  1) Remote wins  2) Local wins  3) Abort"
    printf "Choice: "; read -r choice
    case "$choice" in
      2) for f in "${conflicts[@]}"; do git checkout -- "$f" 2>/dev/null || true; done ;;
      3) info "Aborted."; exit 0 ;;
    esac
  fi

  git pull origin "$branch"
  repo_to_skills
  repo_to_plugins_meta
  update_device_log
  git add devices.log
  git commit -m "device: sync pull on ${DEVICE}" 2>/dev/null || true
  git push 2>/dev/null || true

  success "Pull complete. $incoming file(s) updated."
  print_plugin_restore_commands
}

cmd_status() {
  if [[ ! -d "$REPO_DIR/.git" ]]; then
    warn "Not initialized. Run: sync.sh init"
    exit 0
  fi
  check_ssh
  cd "$REPO_DIR"
  git fetch origin --quiet

  local branch; branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "main")
  echo -e "\n${CYAN}=== Skill Sync Status ===${NC}"
  echo -e "Device : ${YELLOW}${DEVICE}${NC}"
  echo -e "Repo   : ${YELLOW}$(git remote get-url origin)${NC}"
  echo ""

  skills_to_repo
  plugins_meta_to_repo

  local unstaged; unstaged=$(git diff --name-only 2>/dev/null || true)
  local untracked; untracked=$(git ls-files --others --exclude-standard 2>/dev/null || true)
  local remote_changes; remote_changes=$(git diff HEAD..origin/"$branch" --name-only 2>/dev/null || true)

  [[ -n "$unstaged" ]] && echo "$unstaged" | while read -r f; do echo -e "  ${YELLOW}≠ modified${NC}   $f"; done
  [[ -n "$untracked" ]] && echo "$untracked" | while read -r f; do echo -e "  ${GREEN}+ local only${NC} $f"; done
  [[ -n "$remote_changes" ]] && echo "$remote_changes" | while read -r f; do echo -e "  ${CYAN}↓ remote newer${NC} $f"; done
  [[ -z "$unstaged" && -z "$untracked" && -z "$remote_changes" ]] && echo -e "  ${GREEN}✓ fully synced${NC}"

  local behind; behind=$(git rev-list HEAD..origin/"$branch" --count 2>/dev/null || echo 0)
  local ahead; ahead=$(git rev-list origin/"$branch"..HEAD --count 2>/dev/null || echo 0)
  echo -e "\nCommits ahead : $ahead  |  behind : $behind"
  git checkout -- . 2>/dev/null || true
}

cmd_devices() {
  [[ -d "$REPO_DIR/.git" ]] || error "Not initialized. Run: sync.sh init"
  local log="$REPO_DIR/devices.log"
  [[ -f "$log" ]] || { info "No devices registered yet."; exit 0; }
  echo -e "\n${CYAN}=== Registered Devices ===${NC}"
  printf "%-30s %-10s %s\n" "HOSTNAME" "OS" "LAST SYNC"
  echo "──────────────────────────────────────────────────────"
  while IFS=$'\t' read -r h os ts; do
    printf "%-30s %-10s %s\n" "$h" "$os" "$ts"
  done < "$log"
  echo ""
}

# ── Entry point ───────────────────────────────────────────────────────────────
check_deps

case "${1:-help}" in
  init)    cmd_init "${2:-}" ;;
  push)    cmd_push ;;
  pull)    cmd_pull ;;
  status)  cmd_status ;;
  devices) cmd_devices ;;
  *)
    echo -e "${CYAN}skill-sync${NC} — Claude skills + plugins ↔ GitHub"
    echo ""
    echo "Commands:"
    echo "  init              Guided first-time setup"
    echo "  init <repo_url>   First-time setup with repo URL"
    echo "  push              Push local changes to GitHub"
    echo "  pull              Pull from GitHub"
    echo "  status            Show sync state"
    echo "  devices           List registered devices"
    ;;
esac
