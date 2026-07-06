---
name: store-secret
description: Internal helper — use when the app needs an API key, token, or webhook URL from the builder to talk to another service. This is NOT a phrase the builder says; trigger it whenever you're building a feature that needs a credential. Collects the value in plain language and stores it safely, never showing jargon.
---

# store-secret

When a feature needs a credential (a webhook URL, an API key, a token), get it
from the builder in plain words and store it on the app's Netlify site — never
in the code.

## Steps

1. Ask for it plainly: *"To connect to Slack I need your webhook link — paste it
   here."* Don't say "environment variable", "secret", or "API key" unless they
   do.
2. Store it on the site, scoped to this app: `netlify env:set <NAME> "<value>"`
   (encrypted, per-site).
3. Read it in server code from `process.env.<NAME>`, in a route under `app/api/`.
4. It reaches previews and production automatically; if it was added after the
   last build, a fresh "save a preview" / "make it live" picks it up.
5. **If `netlify env:set` fails** with *"Missing required path variable 'account_id'"*
   (or similar), the builder's Netlify sign-in isn't a member of the team that owns this
   site — you can't store it from here. Don't show the raw error; say plainly: *"I can't
   save this from here — your Netlify sign-in isn't on the team that owns this app. Your
   admin needs to add you, or re-issue your Netlify token from the team account."*
   (See SETUP.md.)

## Never

- Never write the value into a file, commit it, or print it back to the builder.
- Never expose it to the browser — only read it in server code (`app/api/...`).
- One app's keys never touch another app (per-site scope).
