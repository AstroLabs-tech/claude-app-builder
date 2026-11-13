---
name: show-me
description: Run the app locally so the builder can see it on their own computer. Use whenever they say "show me", "let me see it", "run it", "open it", "can I see what it looks like", or otherwise want to view the current app. Local only — nothing is published or shared.
---

# show-me

Start the app on the builder's machine and hand back the private link.

## Steps

1. If `node_modules` is missing, run `npm install` first (tell them once that
   you're "getting things ready").
2. Start the dev server in the background **with the app's test sign-in codes**
   passed straight from the app's site (nothing written to disk):
   ```bash
   set -o pipefail
   get() { netlify env:get "$1" --context dev --json | jq -er --arg k "$1" '.[$k] // ""' | tr -d '\r'; }
   PK=$(get NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY) && SK=$(get CLERK_SECRET_KEY) \
     || { echo "couldn't read this app's settings — stop" >&2; exit 1; }
   [ -n "$PK" ] && [ -n "$SK" ] || { echo "no test sign-in codes — stop" >&2; exit 1; }
   NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY="$PK" CLERK_SECRET_KEY="$SK" npm run dev
   ```
   This is Next.js, so it serves the whole app, usually at http://localhost:3000.
   - If the check stops it, sign-in isn't set up for this app yet: say *"Your
     admin still needs to set up sign-in for this app — once they send the two
     codes, I can show it to you,"* and stop. Never work around it by switching
     sign-in off.
   - Only if they specifically need saved data to work locally, use
     `npm run dev:netlify` instead (it brings the codes in by itself).
3. Read the address **this** server prints (`Local: http://localhost:<port>`) —
   if 3000 was taken, Next picks another port — and wait until that address responds
   before replying. Never treat something else answering on 3000 as this app.

## Reply

> "Here you go: <the address this server printed> — this is running just on your computer and
> updates live as we change things. Sign in with your work account; only you can
> see this one."

## Never

- Never say "server", "localhost", "port", or "dev mode" to the builder.
- Never publish or share anything — this step is local only.
