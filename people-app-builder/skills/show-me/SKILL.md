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
   PK=$(netlify env:get NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY --context dev)
   SK=$(netlify env:get CLERK_SECRET_KEY --context dev)
   NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY="$PK" CLERK_SECRET_KEY="$SK" npm run dev
   ```
   This is Next.js, so it serves the whole app at **http://localhost:3000**.
   - If either code is empty, sign-in isn't set up for this app yet: say *"Your
     admin still needs to set up sign-in for this app — once they send the two
     codes, I can show it to you,"* and stop. Never work around it by switching
     sign-in off.
   - Only if they specifically need saved data to work locally, use
     `npm run dev:netlify` instead (it brings the codes in by itself).
3. Wait until it is actually serving (the server reports ready / responds on
   :3000) before replying — don't hand over a link that isn't up yet.
4. If something else is already on port 3000, use the port Next picks instead and
   give them that link.

## Reply

> "Here you go: http://localhost:3000 — this is running just on your computer and
> updates live as we change things. Sign in with your work account; only you can
> see this one."

## Never

- Never say "server", "localhost", "port", or "dev mode" to the builder.
- Never publish or share anything — this step is local only.
