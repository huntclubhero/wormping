# WormPing 🪱💣

**Worms Armageddon voice notifications for Claude Code, Codex, Cursor, and any AI agent.**

Stop babysitting your terminal. Deploy a Worm today.

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/import/project?template=https://github.com/huntclubhero/wormping)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## What is WormPing?

AI coding agents don't tell you when they're done or need permission. You end up staring at your terminal like a worm staring at a holy hand grenade.

**WormPing fixes this.** It plays real Worms Armageddon voice lines at key moments:

| Hook Event | Sound | What Happens |
|------------|-------|-------------|
| `SessionStart` | "Incoming!" | Your worm greets you |
| `Notification` (permission_prompt) | "Come on then!" | Your agent needs approval |
| `Stop` | "Brilliant!" | Agent finished, your turn to act |

## Install

```bash
curl -fsSL https://wormping.vercel.app/install.sh | bash
```

Pick your packs:

```bash
curl -fsSL https://wormping.vercel.app/install.sh | bash -s english angry_scots rasta
```

## Voice Packs

20 real soundbanks from Worms Armageddon, each with 32 voice lines:

| Pack | Accent | Key |
|------|--------|-----|
| English (Default) | Standard Worms | `english` |
| Angry Scots | Scottish | `angry_scots` |
| Rasta | Jamaican | `rasta` |
| The Raj | British Colonial | `the_raj` |
| Drill Sergeant | Military | `drillsgt` |
| French | French | `french` |
| Brooklyn | New York | `brooklyn` |
| Soul Man | Soul/Funk | `soul_man` |
| Scouser | Liverpool | `scouser` |
| Australian | Australian | `australian` |
| Irish | Irish | `irish` |
| Redneck | Southern US | `redneck` |
| Cyberworms | Robotic/Alien | `alien` |
| Wideboy | Tough Guy | `action_hero` |
| Thespian | Dramatic | `thespian` |
| Geezer | London | `geezer` |
| Stiff Upper Lip | Posh British | `grandpa` |
| Kidz | High-pitched | `squeaky` |
| Team17 Test | Dev Team | `teamster` |
| Wacky | Zany | `pirate` |

## Usage

```bash
# Play a sound by category
wormping play greeting
wormping play complete
wormping play error

# List available packs
wormping list

# Set volume (0 to 100)
wormping volume 60

# Check config
wormping config
```

## How It Works

WormPing hooks into your AI coding tools via their event systems:

1. **Claude Code**: Uses the hooks system (`~/.claude/hooks.json`) with `SessionStart`, `Stop`, and `Notification` events
2. **Cursor / Windsurf**: Uses extension hooks
3. **Any MCP Client**: Exposes a `play_sound` tool

When an event fires, WormPing picks a random voice line from your selected pack and plays it through your system audio.

## Supported Tools

- Claude Code
- Codex
- Cursor
- Windsurf
- OpenCode
- Kiro
- Any tool with shell hooks or MCP support

## Features

- **Real game audio**: Actual WAV files from Worms Armageddon, converted to MP3
- **20 voice packs**: Every accent from the game
- **No repeats**: Tracks last-played per category
- **Volume control**: 0 to 100 via config
- **Category toggles**: Enable/disable any event type
- **Cross-platform**: macOS (`afplay`), Linux (`paplay`/`aplay`/`mpv`/`ffplay`), Windows (`ffplay` preferred, PowerShell fallback)
- **Tab titles**: Terminal tab shows project name + status
- **Desktop notifications**: Push alerts when your terminal is in the background

## Attribution

Sound files are from **Worms Armageddon** by **Team17 Digital Limited**.
Worms is a registered trademark of Team17.
This is a fan project and is not affiliated with or endorsed by Team17.

Inspired by [PeonPing](https://www.peonping.com/) by the PeonPing community.

## License

MIT

---

Built with 💣 by [@huntclubhero](https://github.com/huntclubhero)
