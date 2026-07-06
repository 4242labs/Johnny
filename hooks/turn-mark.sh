#!/usr/bin/env bash
# Claude Code UserPromptSubmit hook — stamp the start of a turn for johnny'
# hybrid Stop hook AND the `hey` idle gate. Only touches a marker for sessions
# where voice (.alias) OR hey (.hey) is active; no-ops for everything else.
# Pair with voice-speak.sh / hey.sh.
sid=""
payload="$(cat 2>/dev/null)"
[ -n "$payload" ] && sid="$(printf '%s' "$payload" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("session_id",""))' 2>/dev/null)"
[ -z "$sid" ] && sid="${CLAUDE_CODE_SESSION_ID:-}"
[ -z "$sid" ] && exit 0
CACHE="${VOICE_CACHE:-${TMPDIR:-/tmp}/johnny-cache}"
[ -f "$CACHE/$sid.alias" ] || exit 0   # voice not active for this session
: > "$CACHE/$sid.turn" 2>/dev/null
exit 0
