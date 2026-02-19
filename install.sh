#!/usr/bin/env bash
# WormPing Installer
# Worms-themed sound notifications for Claude Code
#
# Usage:
#   curl -fsSL wormping.vercel.app/install.sh | bash
#   curl -fsSL wormping.vercel.app/install.sh | bash -s english angry_scots rasta
#
# Available packs: english, angry_scots, rasta, pirate, french, irish,
#   australian, brooklyn, drillsgt, geezer, grandpa, redneck, scouser,
#   soul_man, squeaky, teamster, the_raj, thespian, action_hero, alien

set -euo pipefail

WORMPING_BASE_URL="${WORMPING_BASE_URL:-https://wormping.vercel.app}"
WORMPING_DIR="$HOME/.wormping"
SOUNDS_DIR="$WORMPING_DIR/sounds"
CONFIG_FILE="$WORMPING_DIR/config"
STATE_FILE="$WORMPING_DIR/state"
CLAUDE_HOOKS_FILE="$HOME/.claude/hooks.json"

# All available sound files per pack
ALL_SOUNDS=(
  AMAZING BORING BRILLIANT BUMMER BYEBYE COMEONTHEN COWARD EXCELLENT
  FATALITY FIRE FIRSTBLOOD FLAWLESS GOAWAY GRENADE HELLO HURRY ILLGETYOU
  INCOMING JUSTYOUWAIT KAMIKAZE LEAVEMEALONE MISSED OHDEAR OOPS OUCH
  PERFECT REVENGE RUNAWAY TAKECOVER VICTORY WATCHTHIS YESSIR
)

# Available voice packs
AVAILABLE_PACKS=(
  action_hero alien angry_scots australian brooklyn drillsgt english french
  geezer grandpa irish pirate rasta redneck scouser soul_man squeaky
  teamster the_raj thespian
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_worm() {
  echo ""
  echo -e "${GREEN}    ___       ___${NC}"
  echo -e "${GREEN}   /   \\     /   \\${NC}"
  echo -e "${GREEN}  | ${CYAN}O O${GREEN} |   | WormPing |${NC}"
  echo -e "${GREEN}   \\___/     \\___/${NC}"
  echo -e "${GREEN}    |||${NC}"
  echo -e "${GREEN}    |||  ${BOLD}${YELLOW}\"INCOMING!\"${NC}"
  echo -e "${GREEN}   /|||\\${NC}"
  echo ""
}

log_info() {
  echo -e "${CYAN}[wormping]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[wormping]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[wormping]${NC} $1"
}

log_error() {
  echo -e "${RED}[wormping]${NC} $1"
}

# Validate pack name against known packs
validate_pack() {
  local pack="$1"
  for valid in "${AVAILABLE_PACKS[@]}"; do
    if [ "$pack" = "$valid" ]; then
      return 0
    fi
  done
  return 1
}

# Download a single sound file with retries
download_sound() {
  local pack="$1"
  local sound="$2"
  local url="${WORMPING_BASE_URL}/sounds/${pack}/${sound}.mp3"
  local dest="${SOUNDS_DIR}/${pack}/${sound}.mp3"
  local retries=3
  local attempt=1

  while [ $attempt -le $retries ]; do
    if curl -fsSL --connect-timeout 10 --max-time 30 -o "$dest" "$url" 2>/dev/null; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 1
  done

  log_warn "Failed to download: ${pack}/${sound}.mp3 (tried ${retries} times)"
  return 1
}

# Download all sounds for a pack
download_pack() {
  local pack="$1"
  local pack_dir="${SOUNDS_DIR}/${pack}"
  local downloaded=0
  local failed=0

  mkdir -p "$pack_dir"

  log_info "Downloading sound pack: ${BOLD}${pack}${NC}"

  for sound in "${ALL_SOUNDS[@]}"; do
    if download_sound "$pack" "$sound"; then
      downloaded=$((downloaded + 1))
    else
      failed=$((failed + 1))
    fi
    # Progress indicator
    printf "\r  Progress: %d/%d files" $((downloaded + failed)) ${#ALL_SOUNDS[@]}
  done
  echo ""

  if [ $failed -gt 0 ]; then
    log_warn "Pack '${pack}': ${downloaded} downloaded, ${failed} failed"
  else
    log_success "Pack '${pack}': all ${downloaded} sounds downloaded"
  fi

  return 0
}

# Create the wormping player script
create_player_script() {
  local script_path="$WORMPING_DIR/wormping"

  cat > "$script_path" << 'PLAYER_SCRIPT'
#!/usr/bin/env bash
# WormPing: Worms-themed sound player for Claude Code
# Play classic Worms voice lines as coding notifications

set -uo pipefail

WORMPING_DIR="$HOME/.wormping"
SOUNDS_DIR="$WORMPING_DIR/sounds"
CONFIG_FILE="$WORMPING_DIR/config"
STATE_FILE="$WORMPING_DIR/state"

# Category to sound file mappings
declare -A CATEGORY_MAP
CATEGORY_MAP=(
  [greeting]="INCOMING HELLO FIRSTBLOOD"
  [permission]="COMEONTHEN HURRY JUSTYOUWAIT"
  [complete]="BRILLIANT EXCELLENT VICTORY PERFECT"
  [error]="OOPS MISSED BUMMER"
  [annoyed]="GOAWAY LEAVEMEALONE BORING"
  [acknowledge]="AMAZING WATCHTHIS YESSIR"
)

ALL_CATEGORIES="greeting permission complete error annoyed acknowledge"

# Load config (defaults)
load_config() {
  WORMPING_PACK="english"
  WORMPING_VOLUME="80"
  WORMPING_ENABLED="true"

  if [ -f "$CONFIG_FILE" ]; then
    while IFS='=' read -r key value; do
      case "$key" in
        pack) WORMPING_PACK="$value" ;;
        volume) WORMPING_VOLUME="$value" ;;
        enabled) WORMPING_ENABLED="$value" ;;
      esac
    done < "$CONFIG_FILE"
  fi
}

# Save config
save_config() {
  cat > "$CONFIG_FILE" << EOF
pack=${WORMPING_PACK}
volume=${WORMPING_VOLUME}
enabled=${WORMPING_ENABLED}
EOF
}

# Load state (last played per category)
load_state() {
  declare -gA LAST_PLAYED
  if [ -f "$STATE_FILE" ]; then
    while IFS='=' read -r key value; do
      LAST_PLAYED["$key"]="$value"
    done < "$STATE_FILE"
  fi
}

# Save state
save_state() {
  : > "$STATE_FILE"
  for key in "${!LAST_PLAYED[@]}"; do
    echo "${key}=${LAST_PLAYED[$key]}" >> "$STATE_FILE"
  done
}

# Resolve ffplay binary: check PATH, then cached path, then search common locations
resolve_ffplay() {
  # 1. Already in PATH
  if command -v ffplay >/dev/null 2>&1; then
    command -v ffplay
    return 0
  fi

  # 2. Cached from a previous run
  local cache_file="$WORMPING_DIR/.ffplay_path"
  if [ -f "$cache_file" ]; then
    local cached
    cached="$(cat "$cache_file")"
    if [ -x "$cached" ]; then
      echo "$cached"
      return 0
    fi
  fi

  # 3. Search common Windows locations
  local home="${HOME:-}"
  local user="${USER:-${USERNAME:-unknown}}"
  [ -z "$home" ] && home="/c/Users/$user"
  local dirs=(
    "$home/AppData/Local/Microsoft/WinGet/Links"
    "$home/scoop/shims"
    "/c/ProgramData/chocolatey/bin"
    "/c/ffmpeg/bin"
  )
  for d in "${dirs[@]}"; do
    if [ -x "$d/ffplay" ] || [ -x "$d/ffplay.exe" ]; then
      echo "$d/ffplay"
      return 0
    fi
  done

  # 4. Deep search winget packages (ffplay is buried in subdirs)
  local winget_dir="$home/AppData/Local/Microsoft/WinGet/Packages"
  if [ -d "$winget_dir" ]; then
    local found
    found="$(find "$winget_dir" -maxdepth 5 -name 'ffplay.exe' 2>/dev/null | head -1)"
    if [ -n "$found" ] && [ -x "$found" ]; then
      echo "$found"
      return 0
    fi
  fi

  return 1
}

# Play a sound file
play_sound() {
  local file="$1"

  if [ ! -f "$file" ]; then
    echo "Error: Sound file not found: $file" >&2
    return 1
  fi

  case "$(uname -s)" in
    Darwin*)
      local vol
      vol=$(echo "scale=2; ${WORMPING_VOLUME}/100" | bc 2>/dev/null || echo "0.8")
      afplay -v "$vol" "$file"
      return $?
      ;;
    Linux*)
      if command -v paplay >/dev/null 2>&1; then
        local vol=$(( WORMPING_VOLUME * 655 ))
        paplay --volume="$vol" "$file"
      elif command -v aplay >/dev/null 2>&1; then
        aplay -q "$file"
      elif command -v ffplay >/dev/null 2>&1; then
        ffplay -nodisp -autoexit -volume "$WORMPING_VOLUME" "$file" >/dev/null 2>&1
      elif command -v mpv >/dev/null 2>&1; then
        mpv --no-video --volume="$WORMPING_VOLUME" "$file" >/dev/null 2>&1
      else
        echo "Error: No audio player found (install pulseaudio, ffplay, or mpv)" >&2
        return 1
      fi
      return $?
      ;;
  esac

  # Windows (MINGW/MSYS/CYGWIN) and generic fallback: use ffplay
  local ffplay_bin
  ffplay_bin="$(resolve_ffplay 2>/dev/null)" || {
    echo "Error: ffplay not found. Install ffmpeg: winget install ffmpeg" >&2
    return 1
  }

  # Cache the path for future hook subprocess calls
  echo "$ffplay_bin" > "$WORMPING_DIR/.ffplay_path" 2>/dev/null

  "$ffplay_bin" -nodisp -autoexit -volume "$WORMPING_VOLUME" "$file" >/dev/null 2>&1
}

# Pick a random sound from a category, avoiding the last played
pick_sound() {
  local category="$1"
  local sounds_str="${CATEGORY_MAP[$category]:-}"

  if [ -z "$sounds_str" ]; then
    echo "Error: Unknown category '$category'" >&2
    echo "Available: $ALL_CATEGORIES" >&2
    return 1
  fi

  read -ra sounds <<< "$sounds_str"
  local count=${#sounds[@]}

  if [ $count -eq 0 ]; then
    echo "Error: No sounds mapped for category '$category'" >&2
    return 1
  fi

  load_state
  local last="${LAST_PLAYED[$category]:-}"

  if [ $count -eq 1 ]; then
    echo "${sounds[0]}"
    return 0
  fi

  # Pick random, avoiding last played
  local attempts=0
  local pick
  while [ $attempts -lt 10 ]; do
    local idx=$(( RANDOM % count ))
    pick="${sounds[$idx]}"
    if [ "$pick" != "$last" ]; then
      break
    fi
    attempts=$((attempts + 1))
  done

  LAST_PLAYED["$category"]="$pick"
  save_state
  echo "$pick"
}

# Command: play a category
cmd_play() {
  local category="${1:-}"

  if [ -z "$category" ]; then
    echo "Usage: wormping play <category>"
    echo "Categories: $ALL_CATEGORIES"
    return 1
  fi

  load_config

  if [ "$WORMPING_ENABLED" != "true" ]; then
    return 0
  fi

  local sound
  sound="$(pick_sound "$category")" || return 1

  local file="${SOUNDS_DIR}/${WORMPING_PACK}/${sound}.mp3"

  if [ ! -f "$file" ]; then
    file="${SOUNDS_DIR}/english/${sound}.mp3"
    if [ ! -f "$file" ]; then
      echo "Error: Sound file not found for ${WORMPING_PACK}/${sound}.mp3" >&2
      return 1
    fi
  fi

  play_sound "$file"
}

# Command: list available packs and categories
cmd_list() {
  echo "WormPing Sound Browser"
  echo "======================"
  echo ""

  echo "Installed packs:"
  if [ -d "$SOUNDS_DIR" ]; then
    for pack_dir in "$SOUNDS_DIR"/*/; do
      if [ -d "$pack_dir" ]; then
        local pack_name
        pack_name="$(basename "$pack_dir")"
        local count
        count="$(find "$pack_dir" -name '*.mp3' 2>/dev/null | wc -l | tr -d ' ')"
        echo "  $pack_name ($count sounds)"
      fi
    done
  else
    echo "  (none installed)"
  fi

  echo ""
  echo "Categories:"
  for cat in $ALL_CATEGORIES; do
    echo "  $cat: ${CATEGORY_MAP[$cat]}"
  done

  echo ""
  load_config
  echo "Active pack: $WORMPING_PACK"
  echo "Volume: ${WORMPING_VOLUME}%"
  echo "Enabled: $WORMPING_ENABLED"
}

# Command: config
cmd_config() {
  local key="${1:-}"
  local value="${2:-}"

  load_config

  if [ -z "$key" ]; then
    echo "Current config:"
    echo "  pack=$WORMPING_PACK"
    echo "  volume=$WORMPING_VOLUME"
    echo "  enabled=$WORMPING_ENABLED"
    echo ""
    echo "Usage: wormping config <key> <value>"
    echo "Keys: pack, volume, enabled"
    return 0
  fi

  case "$key" in
    pack)
      if [ -z "$value" ]; then
        echo "Current pack: $WORMPING_PACK"
        return 0
      fi
      if [ ! -d "${SOUNDS_DIR}/${value}" ]; then
        echo "Error: Pack '${value}' is not installed" >&2
        echo "Installed packs:"
        ls "$SOUNDS_DIR" 2>/dev/null || echo "  (none)"
        return 1
      fi
      WORMPING_PACK="$value"
      save_config
      echo "Pack set to: $value"
      ;;
    volume)
      if [ -z "$value" ]; then
        echo "Current volume: ${WORMPING_VOLUME}%"
        return 0
      fi
      if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 0 ] || [ "$value" -gt 100 ]; then
        echo "Error: Volume must be a number between 0 and 100" >&2
        return 1
      fi
      WORMPING_VOLUME="$value"
      save_config
      echo "Volume set to: ${value}%"
      ;;
    enabled)
      if [ -z "$value" ]; then
        echo "Enabled: $WORMPING_ENABLED"
        return 0
      fi
      if [ "$value" != "true" ] && [ "$value" != "false" ]; then
        echo "Error: Enabled must be 'true' or 'false'" >&2
        return 1
      fi
      WORMPING_ENABLED="$value"
      save_config
      echo "Enabled set to: $value"
      ;;
    *)
      echo "Error: Unknown config key '$key'" >&2
      echo "Keys: pack, volume, enabled" >&2
      return 1
      ;;
  esac
}

# Command: volume shortcut
cmd_volume() {
  local value="${1:-}"
  if [ -z "$value" ]; then
    load_config
    echo "Volume: ${WORMPING_VOLUME}%"
    echo "Usage: wormping volume <0-100>"
    return 0
  fi
  cmd_config "volume" "$value"
}

# Command: test all categories
cmd_test() {
  echo "Testing all WormPing categories..."
  echo ""
  for cat in $ALL_CATEGORIES; do
    echo "Playing: $cat"
    cmd_play "$cat"
    sleep 2
  done
  echo ""
  echo "Test complete!"
}

# Show help
cmd_help() {
  echo "WormPing: Worms-themed sound notifications for Claude Code"
  echo ""
  echo "Usage: wormping <command> [args]"
  echo ""
  echo "Commands:"
  echo "  play <category>    Play a random sound from a category"
  echo "  list               Show installed packs and categories"
  echo "  config [key] [val] View or set configuration"
  echo "  volume [0-100]     Get or set volume level"
  echo "  test               Play one sound from each category"
  echo "  help               Show this help message"
  echo ""
  echo "Categories: $ALL_CATEGORIES"
  echo ""
  echo "Examples:"
  echo "  wormping play greeting"
  echo "  wormping config pack angry_scots"
  echo "  wormping volume 60"
}

# Main entry point
main() {
  local command="${1:-help}"
  shift 2>/dev/null || true

  case "$command" in
    play)       cmd_play "$@" ;;
    list)       cmd_list "$@" ;;
    config)     cmd_config "$@" ;;
    volume)     cmd_volume "$@" ;;
    test)       cmd_test "$@" ;;
    help|h)     cmd_help "$@" ;;
    *)
      echo "Error: Unknown command '$command'" >&2
      echo "Run 'wormping help' for usage" >&2
      return 1
      ;;
  esac
}

main "$@"
PLAYER_SCRIPT

  chmod +x "$script_path"
  log_success "Player script installed at: $script_path"
}

# Add wormping to PATH in shell rc files
add_to_path() {
  local path_line='export PATH="$HOME/.wormping:$PATH"'
  local added=false

  for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$rc_file" ]; then
      if ! grep -qF '.wormping' "$rc_file" 2>/dev/null; then
        echo "" >> "$rc_file"
        echo "# WormPing: Worms-themed sound notifications" >> "$rc_file"
        echo "$path_line" >> "$rc_file"
        log_success "Added to PATH in: $(basename "$rc_file")"
        added=true
      else
        log_info "PATH already configured in: $(basename "$rc_file")"
        added=true
      fi
    fi
  done

  # If neither .bashrc nor .zshrc exists, create .bashrc entry
  if [ "$added" = false ]; then
    echo "" >> "$HOME/.bashrc"
    echo "# WormPing: Worms-themed sound notifications" >> "$HOME/.bashrc"
    echo "$path_line" >> "$HOME/.bashrc"
    log_success "Added to PATH in: .bashrc (created)"
  fi

  # Also export for current session
  export PATH="$WORMPING_DIR:$PATH"
}

# Setup Claude Code hooks
setup_claude_hooks() {
  local claude_dir="$HOME/.claude"
  local wormping_cmd="$WORMPING_DIR/wormping"

  mkdir -p "$claude_dir"

  if [ -f "$CLAUDE_HOOKS_FILE" ]; then
    # Check if hooks already have wormping entries
    if grep -q "wormping" "$CLAUDE_HOOKS_FILE" 2>/dev/null; then
      log_info "Claude Code hooks already configured with WormPing"
      return 0
    fi

    # File exists but no wormping hooks: we need to merge carefully
    # Back up existing hooks
    cp "$CLAUDE_HOOKS_FILE" "${CLAUDE_HOOKS_FILE}.bak"
    log_info "Backed up existing hooks.json to hooks.json.bak"
  fi

  # Write the hooks configuration
  # Using a heredoc with proper JSON formatting
  cat > "$CLAUDE_HOOKS_FILE" << HOOKS_JSON
{
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "${wormping_cmd} play greeting",
        "async": true
      }
    ],
    "Stop": [
      {
        "type": "command",
        "command": "${wormping_cmd} play complete",
        "async": true
      }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "${wormping_cmd} play permission",
            "async": true
          }
        ]
      }
    ]
  }
}
HOOKS_JSON

  log_success "Claude Code hooks configured at: $CLAUDE_HOOKS_FILE"
  log_info "  SessionStart             : plays a greeting sound"
  log_info "  Stop                     : plays when agent finishes responding"
  log_info "  Notification (permission): plays when agent needs approval"
}

# Write default config
write_default_config() {
  local default_pack="${1:-english}"

  if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" << EOF
pack=${default_pack}
volume=80
enabled=true
EOF
    log_success "Default config written (pack: ${default_pack}, volume: 80%)"
  else
    log_info "Config file already exists, keeping current settings"
  fi

  # Initialize empty state file
  if [ ! -f "$STATE_FILE" ]; then
    touch "$STATE_FILE"
  fi
}

# Main installer
main() {
  print_worm

  echo -e "${BOLD}WormPing Installer${NC}"
  echo "Worms-themed sound notifications for Claude Code"
  echo ""

  # Determine which packs to install
  local packs=("$@")
  if [ ${#packs[@]} -eq 0 ]; then
    packs=("english")
  fi

  # Validate all requested packs
  for pack in "${packs[@]}"; do
    if ! validate_pack "$pack"; then
      log_error "Unknown pack: '${pack}'"
      echo ""
      echo "Available packs:"
      printf "  %s\n" "${AVAILABLE_PACKS[@]}"
      exit 1
    fi
  done

  log_info "Packs to install: ${packs[*]}"
  echo ""

  # Step 1: Create directories
  log_info "Creating directories..."
  mkdir -p "$WORMPING_DIR"
  mkdir -p "$SOUNDS_DIR"
  log_success "Created: $WORMPING_DIR"

  # Step 2: Download sound packs
  echo ""
  log_info "Downloading sound packs..."
  echo ""
  for pack in "${packs[@]}"; do
    download_pack "$pack"
  done

  # Step 3: Install player script
  echo ""
  log_info "Installing WormPing player..."
  create_player_script

  # Step 4: Write default config (use first specified pack)
  write_default_config "${packs[0]}"

  # Step 5: Add to PATH
  echo ""
  log_info "Configuring PATH..."
  add_to_path

  # Step 6: Setup Claude Code hooks
  echo ""
  log_info "Setting up Claude Code hooks..."
  setup_claude_hooks

  # Done!
  echo ""
  echo -e "${GREEN}================================================${NC}"
  echo -e "${GREEN}  ${BOLD}INCOMING!${NC} ${GREEN}WormPing is ready for battle!${NC}"
  echo -e "${GREEN}================================================${NC}"
  echo ""
  echo -e "  Installed packs : ${BOLD}${packs[*]}${NC}"
  echo -e "  Player script   : ${BOLD}${WORMPING_DIR}/wormping${NC}"
  echo -e "  Sound files     : ${BOLD}${SOUNDS_DIR}/${NC}"
  echo -e "  Config          : ${BOLD}${CONFIG_FILE}${NC}"
  echo -e "  Claude hooks    : ${BOLD}${CLAUDE_HOOKS_FILE}${NC}"
  echo ""
  echo "Quick start:"
  echo "  wormping play greeting     | Play a greeting sound"
  echo "  wormping play complete     | Play a completion sound"
  echo "  wormping config pack rasta | Switch voice pack"
  echo "  wormping list              | See all packs and categories"
  echo "  wormping volume 60         | Set volume to 60%"
  echo ""
  echo -e "${YELLOW}Restart your shell or run: source ~/.bashrc${NC}"
  echo ""
  echo -e "${CYAN}\"Come on then!\" Your worm is locked and loaded.${NC}"
  echo ""
}

main "$@"
