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
2. **Create the repo from the template, then clone over HTTPS** (`$BUILDER_GH_ORG`
   is the enterprise builder org from SETUP.md). Avoid `gh … --clone` — it can
   fetch over SSH and hit the wrong account; clone the HTTPS URL explicitly:
   `gh repo create "$BUILDER_GH_ORG/<slug>" --template "$BUILDER_GH_ORG/app-starter" --private`
   then `git clone "https://github.com/$BUILDER_GH_ORG/<slug>.git" && cd <slug>`.
   (If the clone races the template copy and lands empty, just retry it.)
3. **Set up the machine for this app:** `bash scripts/bootstrap.sh`.
4. **Create and connect the Netlify site** with `netlify init` from the app folder.
   This step is **required** — it wires the GitHub→Netlify webhook that makes
   previews and publishing fire. (Don't try to do this purely via the API:
   `createSite` + a deploy key gives you manual builds but **not** that webhook,
   so PRs and merges won't auto-deploy. `netlify init` is the only thing that mints
   the webhook correctly.)
   `netlify init` is an arrow-key menu — drive it precisely (this is where time
   gets lost otherwise):
   - **Action:** the highlighted default is *Connect to an existing project* —
     move **down one** to **Create & configure a new project** and select it.
   - **Team:** AstroLabs Tech Team.
   - **Project name:** a globally-unique slug (per step 1).
   - **Build settings:** accept the detected Next.js defaults (from `netlify.toml`).
   - If you script it with `expect`: match prompts with **`-nocase`** (this expect
     build silently ignores the `(?i)` inline flag — a known time-sink), and send
     a down-arrow (`\033[B`) then Enter for the menu.
   Confirm with `netlify status`. The first app ever connected triggers a one-time
   browser authorization of Netlify on the org; after that it's silent.
5. Confirm the connection is live (the first preview can be triggered by the first
   "save a preview").

## Reply

> "Your new app '<X>' is ready. Want to see it? Just say 'show me'."

## Never

- Never put a Netlify deploy token into the repo — the native integration handles
  deploys. (A Netlify token lives only on this machine, for rollback.)
- Never say "repo", "org", "template", or "deploy" to the builder.
- Never create the repo under an enterprise/SSO personal identity — use the team
  account that owns the builder org.
