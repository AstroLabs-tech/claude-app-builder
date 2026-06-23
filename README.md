# AstroLabs App Builder — Claude Code plugin

Lets non-technical teammates build and ship full-stack web apps with a few plain
phrases — no code, git, or terminal. Powered by Claude Code (in the Claude desktop
app), GitHub (one builder org per team — the ops team uses `AstroLabs-ops`), and Netlify.

## The builder experience (in the Claude Code tab)

- **set up my computer** — one-time: installs the tools + signs you in with your tokens
- **start a new app called X** — provisions a brand-new app
- **show me** — runs it on your computer so you can see it
- **save a preview** — a shareable link; doesn't touch your live site
- **make it live** — publishes it (asks you first)
- **put it back** — instant rollback
- also: say *"make it private"* for password/team-only access, and the agent will
  ask for a key in plain words if an app needs to connect to another service

## Install (each builder, once)

In the Claude Code tab of the Claude desktop app:

```
/plugin marketplace add AstroLabs-tech/claude-app-builder
/plugin install app-builder@astrolabs
```

Then say **set up my computer** and have ready (your admin gives you these):
- your **GitHub access token**
- your **Netlify access token**
- the **org name** your admin gives you (ops team: `AstroLabs-ops`)

## For admins — token provisioning

Issue each builder their own tokens so you can revoke individually and never share
a password:
1. **GitHub** — a classic token (scopes: `repo` + `workflow`) from the team service
   account that's a member of the department's builder org (ops: `AstroLabs-ops`).
   If the enterprise enforces SSO, authorize the token for that org or it can't see it.
2. **Netlify** — a personal access token from the team Netlify account.

Builders authenticate with these tokens only; the shared account's email/password
never leaves your hands. Offboard a builder by revoking their tokens.

## What gets created per app

A private repo in the team's builder org (ops: `AstroLabs-ops`, from its `app-starter` template) + a connected
Netlify site (preview-per-PR, production on merge, instant rollback) + a Netlify DB
provisioned on first publish. See the `app-starter` template for the app itself.
