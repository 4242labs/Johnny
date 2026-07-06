# johnny

A small **speech toolbox** — one CLI (`voice`) that any agent or script can call to
speak, with pluggable TTS engines, named voices, a per-session auto-speak hook, and
**reverse-speak**: when you drive a machine over SSH, its speech plays on *your*
machine instead of the remote box.

- **Named voices** — `voice Fenrir "build is green"`. The name *is* the voice
  (engine · voice · language); no aliases to remember.
- **Pluggable engines** — `say` (macOS built-in), `kokoro` (local, Apache-2.0),
  `eleven` (ElevenLabs cloud). Adding an engine is dropping a file in `engines/`.
- **Reverse-speak over SSH** — speech follows you to wherever you're sitting, with
  only the *text* crossing the wire (the far end synthesizes locally).
- **Attention chime** — a gentle cue plays before each utterance.
- **Multi-agent safe** — per-session audio isolation + a machine-wide playback lock,
  so concurrent agents queue instead of talking over each other.

## Install

```sh
git clone https://github.com/<you>/johnny.git
ln -sf "$PWD/johnny/voice" ~/.local/bin/voice     # ~/.local/bin must be on PATH
```

`voice` resolves its own directory (even through the symlink), so it works from any
repo or session. For the ElevenLabs engine, copy `.env.example` to `.env` and add a key.

## Usage

```sh
voice voices                       # list the available voices: "Name (langs), engine"
voice Fenrir "tests are green"     # single-language voice — just speak
voice Matilda pt "a migração terminou"   # multi-language voice — give the language
voice say "quick and robotic"      # call an engine directly
echo "piped text works too" | voice
voice list                         # engines + availability
voice bench "compare the engines"  # play through every available engine
```

A voice whose name maps to one language needs no language argument; a voice that
serves several (e.g. an ElevenLabs voice doing both `en` and `pt`) will tell you which
languages it offers if you don't pick one.

### Voices

Defined in `config.sh` (`voice_registry`) — edit it to add your own. Each row is
`Name | engine | engine-voice-id | languages`. Example set shipped:

| Voice | Language(s) | Engine |
|-------|-------------|--------|
| Sarah / Dora / Fenrir / Alex | en / pt / en / pt | kokoro |
| Matilda / Charlie | en + pt | eleven |

## Slash command (Claude Code)

Copy `commands/johnny.md` to `~/.claude/commands/johnny.md`. Then:

- `/johnny` — lists the voices and waits for you to pick.
- `/johnny <Name> [lang]` — turns on per-session voice; the agent speaks a short spoken
  gist before each reply (text still carries structure — code, tables, paths).
- `/johnny off` — stops.

## Reverse-speak — play where you sit

By default `voice` plays on the machine it runs on. If that machine is one you're
**driving over SSH**, `voice` instead plays on the machine you connected *from* — it
reads `SSH_CONNECTION`, sends only the text, and the far end synthesizes + plays it.

Setup (on the machine you sit at — the playback target):

1. Enable SSH (so the remote box can reach back).
2. Add the remote box's **dedicated** public key to `~/.ssh/authorized_keys`, pinned to
   the speak command so it can do nothing else:

   ```
   command="/path/to/johnny/server/voice-play",restrict ssh-ed25519 AAAA... johnny-reverse
   ```

3. On the remote box, create that key passphrase-less (`~/.ssh/id_johnny`) so it can
   sign non-interactively, and set `VOICE_SPEAK_USER` in `.env` if your login there
   differs from your login on the playback machine.

Then any `voice` call from an SSH session on the remote box plays on your machine.
Multiplexed SSH (ControlMaster) keeps it fast; if the channel is down the utterance is
dropped rather than played on the unattended box. `VOICE_SPEAK_TARGET=<host>` overrides
the auto-target.

> HTTP alternative: set `VOICE_SINK=http://<host>:8124` and run `server/voice-sink.py`
> on the target (see `server/sink-service.sh` to install it as a service). Reverse-SSH
> is preferred — no daemon, no open port.

## Auto-speak (Stop hook)

Make the active agent speak every reply. Symlink the hook and register it:

```sh
ln -sf "$PWD/johnny/hooks/voice-speak.sh" ~/.local/bin/voice-speak
```

```json
{ "hooks": {
  "UserPromptSubmit": [ { "hooks": [ { "type": "command", "command": "~/johnny/hooks/turn-mark.sh" } ] } ],
  "Stop":             [ { "hooks": [ { "type": "command", "command": "~/johnny/hooks/voice-speak.sh" } ] } ]
} }
```

It speaks the reply only if the agent didn't already speak this turn (never doubles),
and no-ops for sessions where voice isn't active.

## Hey (attention beep)

The mute cousin of auto-speak: instead of a spoken reply, play a short sound when the
agent hands back to you — a finished turn **or** a permission prompt — but *only* if
you've been idle longer than a threshold. A fast back-and-forth stays silent; you're
summoned only when you've likely stepped away.

```sh
voice hey            # list the sounds: ping, chirp, knock, coin, chime
voice hey knock 2 45 # <sound> [times] [idle-threshold-s]; previews once, then active
voice hey off        # stop
```

Wire it on both the `Stop` and `Notification` hooks (share `turn-mark.sh` with auto-speak):

```json
{ "hooks": {
  "UserPromptSubmit": [ { "hooks": [ { "type": "command", "command": "~/johnny/hooks/turn-mark.sh" } ] } ],
  "Stop":             [ { "hooks": [ { "type": "command", "command": "~/johnny/hooks/hey.sh" } ] } ],
  "Notification":     [ { "hooks": [ { "type": "command", "command": "~/johnny/hooks/hey.sh" } ] } ]
} }
```

The beep sounds on the machine where you sit: locally, or — if the agent is driven over
SSH — forwarded over the same reverse channel as speech (dropped, never sounded, if that
box is unattended and the channel is down). The synthesized sounds live in `assets/hey/`
(`ping`, `chirp`, `knock`, `coin`) — regenerate or tweak them with `assets/hey/generate.py`
(pure stdlib, no deps); `chime` reuses the same cue Johnny plays before speech.

## Config

`config.sh` holds the defaults; override any of them via env or a gitignored `.env`:

| Var | Purpose |
|-----|---------|
| `VOICE_ENGINE` / `VOICE_LANG` | default engine / language |
| `VOICE_CHIME` / `VOICE_CHIME_GAP` | attention cue file / pause before speech (`''` disables the chime) |
| `KOKORO_SERVER` | URL of a persistent Kokoro server (see `server/`), else local fallback |
| `ELEVEN_API_KEY` / `ELEVEN_VOICE_ID` | ElevenLabs credentials / voice |
| `VOICE_SPEAK_TARGET` / `VOICE_SPEAK_USER` / `VOICE_SPEAK_KEY` | reverse-speak target / login / key |
| `VOICE_SINK` | HTTP sink URL (alternative to reverse-SSH) |
| `HEY_THRESHOLD` / `HEY_TIMES` / `HEY_GAP` / `HEY_DIR` | hey: default idle seconds / plays / gap between plays / sounds dir |

Never commit a real `ELEVEN_API_KEY` — keep it in the gitignored `.env`.

## Engines

| Engine | Setup | Notes |
|--------|-------|-------|
| `say` | none (macOS built-in) | instant, robotic, local — baseline |
| `kokoro` | `pip install kokoro soundfile` (Python 3.12) | natural, local, en + pt-BR; optional persistent server in `server/` |
| `eleven` | `ELEVEN_API_KEY` in `.env` | best quality, cloud, paid |

## License

GNU Affero General Public License v3.0 (AGPL-3.0). See [LICENSE](LICENSE).
