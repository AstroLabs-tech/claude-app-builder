---
name: new-app
description: Create and wire up a brand-new People-team app from the template. Use when the builder says "start a new app called X", "begin a new project called Y", "create a new app for Z", or otherwise wants to start something new from scratch. (If they already have a prototype, artifact or app, use adopt-existing-app.)
---

# new-app

Provision a fresh People app: a private repo from the People template, set up on
this machine, connected to its own Netlify site, with sign-in turned on. Assumes
the one-time platform setup is done (see the template's SETUP.md) and this machine
is signed in as the People team account.

Fixed for every People app: GitHub org **`AstroLabs-people`**, template
**`AstroLabs-people/app-starter`**, Netlify team **AstroLabs People**.

## Steps

1. **Name it.** Turn what they said into a hyphenated, lowercase slug
   ("performance reviews" → `performance-reviews`). The repo name must be free in
   the org, and the **Netlify site name must be globally unique across all of
   Netlify** — so if the slug is taken, automatically append a short suffix
   (`-app`, `-people`, …). Never make the builder resolve a name collision.
2. **Create the repo from the template, then clone over HTTPS.** Avoid
   `gh … --clone` — it can fetch over SSH and hit the wrong account:
   `gh repo create "AstroLabs-people/<slug>" --template "AstroLabs-people/app-starter" --private`
   then `git clone "https://github.com/AstroLabs-people/<slug>.git" && cd <slug>`.
   (If the clone races the template copy and lands empty, just retry it.)
3. **Set up the machine for this app:** `bash scripts/bootstrap.sh`.
4. **Connect the Netlify site** with `netlify init` — **required**: it mints the
   GitHub→Netlify webhook that makes previews and publishing fire. (The API can't
   replace it — `createSite` + a deploy key gives manual builds but **not** the
   webhook.)

   **Admin prerequisite (once per org, not a builder step):** the Netlify GitHub
   App must already be installed on `AstroLabs-people`. If it isn't, `netlify init`
   404s on the deploy key / *"does the repository exist"* — say plainly *"Your admin
   needs to connect Netlify to the team's GitHub once — I can't do that part,"*
   never a raw error.

   **First, seed the team GitHub token into Netlify's config — then `netlify init`
   needs no GitHub prompt at all.** `netlify init`'s browser authorization grabs the
   builder's personal browser session (wrong account) and is blocked by org OAuth
   restrictions; a seeded direct token sidesteps both:

   ```bash
   CFG="$HOME/Library/Preferences/netlify/config.json"
   [ -f "$CFG" ] || netlify status >/dev/null 2>&1     # ensure the CLI created it
   NID=$(jq -r '.userId // "undefined"' "$CFG" 2>/dev/null); [ -n "$NID" ] || NID=undefined
   jq --arg id "$NID" --arg t "$(gh auth token)" --arg u "$(gh api user --jq .login)" \
     '.users[$id].auth.github = {provider:"github", token:$t, user:$u}' \
     "$CFG" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"
   ```

   Then run `netlify init` and drive only its arrow-key menu:
   - **Action:** default is *Connect to an existing project* — move **down one** to
     **Create & configure a new project**.
   - **Team:** **AstroLabs People**. If that team isn't offered, stop and say
     plainly *"Your Netlify sign-in isn't on the People team yet — your admin needs
     to add you."* Never create a People app in any other team.
   - **Project name:** a globally-unique slug (per step 1).
   - **Build settings:** accept the detected Next.js defaults (from `netlify.toml`).
   - Scripting with `expect`: match with **`-nocase`**, and for each menu **wait for
     it to finish drawing**, then send a down-arrow (`\033[B`) and Enter.

   A clean run ends with **"Success! Netlify CI/CD Configured!"**. Confirm with
   `netlify status`.
5. **Turn on sign-in.** People apps open only for approved people, through Clerk.
   Ask in plain words for the **two sign-in codes for testing** their admin made for
   this app (*"Paste the two sign-in codes your admin sent for this app — they start
   with pk_test_ and sk_test_."*). Store them for local runs and previews only:

   ```bash
   netlify env:set NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY '<pk_test_…>' --context dev deploy-preview branch-deploy >/dev/null
   netlify env:set CLERK_SECRET_KEY '<sk_test_…>' --context dev deploy-preview branch-deploy >/dev/null
   ```

   The **live** codes (`pk_live_` / `sk_live_`) come later from the admin, once the
   app has its real web address; they go on `--context production` only. If the
   builder doesn't have the test codes yet, carry on and say: *"Your admin still
   needs to set up sign-in for this app — once they send the two codes, you'll be
   able to open it."*

   Then put the builder's own work email on the approved list (the
   **who-can-get-in** skill, test list) so they can sign in to their own app.
6. Confirm the connection is live (the first preview can be triggered by the first
   "save a preview").

## Reply

> "Your new app '<X>' is ready, and only approved people can sign in to it. Want to
> see it? Just say 'show me'."

## Never

- Never add a site password or make the app public — sign-in is the only way in.
- Never put test codes on the live app or live codes on previews.
- Never put a Netlify deploy token or any sign-in code into the repo.
- Never use `netlify init`'s browser GitHub authorization — always the seeded team
  token (step 4).
- Never create the app outside `AstroLabs-people` or the AstroLabs People Netlify
  team.
- Never say "repo", "org", "template", "Clerk", "key" or "deploy" to the builder.
