---
name: make-it-private
description: Limit who can open a published app — turn on password or team sign-in protection. Use when the builder says "make it private", "only my team should see this", "password protect it", "it shouldn't be public", or worries about who can open a live or preview link. Apps are public by default; this is the opt-in.
---

# make-it-private

Published apps are public by default. This switches an app to require a password
or team sign-in, through Netlify's access controls.

## Steps

1. Check what they want: a shared **password**, or **team sign-in** (only people
   in the team can open it).
2. Turn on the matching Netlify access protection for the site — through the
   Netlify API/CLI, never by asking them to log in.
3. If it's a password, set it and give it to them once, plainly.

## Reply

> "Done — now only people with the password can open it." (or "…only your team
> can open it.")

## Notes & never

- This changes who can *open* the app; the link itself stays the same.
- Which options exist (password vs. team sign-in) depends on the Netlify plan —
  see SETUP.md. If the one they want isn't available, say so plainly and offer
  the other.
- Never expose how it's wired, and never tell them to use the Netlify dashboard.
