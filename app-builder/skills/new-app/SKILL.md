---
name: new-app
description: Create and wire up a brand-new app from the template. Use when the builder says "start a new app called X", "begin a new project called Y", "create a new app for Z", or otherwise wants to start something new from scratch.
---

# new-app

Provision a fresh app: a private repo from the template, set up on this machine,
connected to its own Netlify site. Assumes the one-time platform setup is done
(see SETUP.md) and this machine is signed in as the team account.

## Steps

1. **Name it.** Turn what they said into a hyphenated, lowercase slug
   ("team directory" → `team-directory`). The repo name must be free in the org,
   and the **Netlify site name must be globally unique across all of Netlify** —
   so if the slug is taken, automatically append a short suffix (`-2`, `-ops`, …)
   or let Netlify assign a random name. Never make a non-technical builder resolve
   a name collision themselves.
2. **Create the repo from the template** (`$BUILDER_GH_ORG` is the enterprise
   builder org from SETUP.md):
   `gh repo create "$BUILDER_GH_ORG/<slug>" --template "$BUILDER_GH_ORG/app-starter" --private --clone`
   then `cd <slug>`.
3. **Set up the machine for this app:** `bash scripts/bootstrap.sh`.
4. **Create and connect the Netlify site** by running `netlify init` from the app
   folder: choose *Create & configure a new project*, the team's Netlify account,
   and a unique site name (per step 1). It wires native continuous deployment
   (preview-per-PR + prod-on-merge), adds the GitHub deploy key + notification
   hooks, and auto-detects Next.js (reading the build command from `netlify.toml`).
   The **first** app ever connected triggers a one-time browser authorization of
   Netlify on the GitHub org; after that, apps connect with no prompt. No deploy
   secrets go in the repo. (More in SETUP.md.)
5. Confirm the connection is live (the first preview can be triggered by the
   first "save a preview").

## Reply

> "Your new app '<X>' is ready. Want to see it? Just say 'show me'."

## Never

- Never put a Netlify deploy token into the repo — the native integration
  handles deploys. (A Netlify token lives only on this machine, for rollback.)
- Never say "repo", "org", "template", or "deploy" to the builder.
- Never create the repo under an enterprise/SSO personal identity — use the team
  account that owns the builder org.
