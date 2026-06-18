---
name: show-me
description: Run the app locally so the builder can see it on their own computer. Use whenever they say "show me", "let me see it", "run it", "open it", "can I see what it looks like", or otherwise want to view the current app. Local only — nothing is published or shared.
---

# show-me

Start the app on the builder's machine and hand back the private link.

## Steps

1. If `node_modules` is missing, run `npm install` first (tell them once that
   you're "getting things ready").
2. Start the dev server in the background: `npm run dev`. This is Next.js, so it
   serves the whole app — pages and backend together — at
   **http://localhost:3000**.
   - Only if they specifically need saved data to work locally, use
     `npm run dev:netlify` instead.
3. Wait until it is actually serving (the server reports ready / responds on
   :3000) before replying — don't hand over a link that isn't up yet.
4. If something else is already on port 3000, use the port Next picks instead and
   give them that link.

## Reply

> "Here you go: http://localhost:3000 — this is running just on your computer and
> updates live as we change things. Only you can see this one."

## Never

- Never say "server", "localhost", "port", or "dev mode" to the builder.
- Never publish or share anything — this step is local only.
