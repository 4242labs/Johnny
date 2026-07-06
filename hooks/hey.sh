#!/usr/bin/env bash
# Claude Code hook — `hey` attention beep. Wire it on BOTH:
#   Stop         → agent finished a turn (an answer, or a prose question)
#   Notification → Claude Code needs you (permission prompt / idle input)
# Beeps ONLY when hey is active for this session ($VOICE_OUT.hey, set by
# `voice hey <sound> ...`) AND you've been idle longer than the threshold —
# now - mtime(.turn) >= threshold. So a fast back-and-forth stays silent; you're
# summoned only when you've likely stepped away. Uniform rule for both hooks.
# The beep always sounds on the machine where the OPERATOR sits: local when the
# agent runs there, else forwarded over Johnny's reverse channel (same key). If
# the agent is remote and that channel is down, the beep is dropped — never
# sounded on an unattended box. Never blocks the turn (fire-and-forget).
src="${BASH_SOURCE[0]:-$0}"
while [ -h "$src" ]; do d="$(cd -P "$(dirname "$src")" && pwd)"; src="$(readlink "$src")"; [ "${src#/}" = "$src" ] && src="$d/$src"; done
HOOK_DIR="$(cd -P "$(dirname "$src")" && pwd)"
VOICE_HOME="$(cd "$HOOK_DIR/.." && pwd)"

payload="$(cat)"
sid="$(printf '%s' "$payload" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("session_id",""))' 2>/dev/null)"
[ -z "$sid" ] && sid="${CLAUDE_CODE_SESSION_ID:-}"
[ -z "$sid" ] && exit 0

export VOICE_HOME VOICE_SESSION="$sid"
. "$VOICE_HOME/config.sh"            # defines VOICE_OUT for THIS session + hey_* helpers

[ -f "$VOICE_OUT.hey" ] || exit 0    # hey not active for this session

read -r sound times thresh < "$VOICE_OUT.hey" 2>/dev/null
[ -n "$sound" ] || exit 0
times="${times:-$HEY_TIMES}"; thresh="${thresh:-$HEY_THRESHOLD}"
file="$(hey_lookup "$sound")" || exit 0
[ -f "$file" ] || exit 0

# Idle gate: seconds since your last prompt (turn-mark stamps .turn). Missing
# marker → treat as "long idle" and beep (fail toward alerting).
if [ -f "$VOICE_OUT.turn" ]; then
  idle="$(python3 -c 'import os,sys,time;print(int(time.time()-os.path.getmtime(sys.argv[1])))' "$VOICE_OUT.turn" 2>/dev/null)"
else
  idle="$thresh"
fi
[ -n "$idle" ] || idle="$thresh"
[ "$idle" -ge "$thresh" ] 2>/dev/null || exit 0

# Fire-and-forget so we never hold up Claude's turn. Beep where the operator is:
# reverse-forward when this box is driven over SSH (drop if that channel's down —
# never beep an unattended box); otherwise play locally.
(
  if [ -z "${VOICE_LOCAL:-}" ] && { [ -n "$VOICE_SPEAK_TARGET" ] || [ -n "${SSH_CONNECTION:-}" ]; }; then
    _hey_reverse "$sound" "$times"
  else
    "$VOICE_HOME/voice" beep "$sound" "$times"
  fi
) >/dev/null 2>&1 &
exit 0
