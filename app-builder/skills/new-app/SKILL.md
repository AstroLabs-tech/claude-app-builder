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
4. **Connect the Netlify site** with `netlify init` — **required**: it mints the
   GitHub→Netlify webhook that makes previews and publishing fire. (The API can't
   replace it — `createSite` + a deploy key gives manual builds but **not** the
   webhook.)

   **Admin prerequisite (once per org, not a builder step):** the Netlify GitHub
   App must already be installed on the builder org with access to its repos (see
   SETUP.md). If it isn't, `netlify init` 404s on the deploy key / *"does the
   repository exist"* — say plainly *"Your admin needs to connect Netlify to the
   team's GitHub once — I can't do that part,"* never a raw error.

   **First, seed the team GitHub token into Netlify's config — then `netlify init`
   needs no GitHub prompt at all.** This is deliberate (validated 2026-06-24): the
   builder org has GitHub *OAuth App access restrictions*, so `netlify init`'s
   browser authorization is **blocked** at the deploy-key step *and* grabs the
   builder's personal browser session (wrong account); driving its "personal access
   token" menu by hand is also unreliable. A seeded direct token sidesteps both — it
   isn't an OAuth app (so the restriction doesn't apply) and there's no menu to
   mis-drive:

   ```bash
   CFG="$HOME/Library/Preferences/netlify/config.json"
   [ -f "$CFG" ] || netlify status >/dev/null 2>&1     # ensure the CLI created it
   NID=$(jq -r '.userId // "undefined"' "$CFG" 2>/dev/null); [ -n "$NID" ] || NID=undefined
   jq --arg id "$NID" --arg t "$(gh auth token)" --arg u "$(gh api user --jq .login)" \
     '.users[$id].auth.github = {provider:"github", token:$t, user:$u}' \
     "$CFG" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"
   ```
   (The token is the builder's own, already on this machine — same trust level as
   their gh login. On a fresh machine the user key may be `undefined`; the snippet
   handles that.)

   Then run `netlify init` and drive only its arrow-key menu — the GitHub step is
   now silent:
   - **Action:** default is *Connect to an existing project* — move **down one** to
     **Create & configure a new project**.
   - **Team:** the platform's Netlify team (AstroLabs Tech Team).
   - **Project name:** a globally-unique slug (per step 1).
   - **Build settings:** accept the detected Next.js defaults (from `netlify.toml`).
   - Scripting with `expect`: match with **`-nocase`** (this build ignores `(?i)`),
     and for each menu **wait for it to finish drawing**, then send a down-arrow
     (`\033[B`) and Enter — sending too early drops the keystroke.

   A clean run ends with **"Success! Netlify CI/CD Configured!"** (deploy key +
   notification hooks). If a wrong GitHub account was cached from an earlier stray
   browser authorization, the seed snippet above replaces it — just re-run. Confirm
   with `netlify status`.
5. Confirm the connection is live (the first preview can be triggered by the first
   "save a preview").

## Reply

> "Your new app '<X>' is ready. Want to see it? Just say 'show me'."

## Never

- Never put a Netlify deploy token into the repo — the native integration handles
  deploys. (A Netlify token lives only on this machine, for rollback.)
- Never use `netlify init`'s browser GitHub authorization — it grabs the builder's
  personal GitHub session, not the team account, and the org's OAuth-app restriction
  blocks it anyway. Always the team token, seeded into Netlify's config (step 4).
- Never say "repo", "org", "template", or "deploy" to the builder.
- Never create the repo under an enterprise/SSO personal identity — use the team
  account that owns the builder org.
