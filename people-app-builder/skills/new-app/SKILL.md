---
name: new-app
description: Create and wire up a brand-new People-team app (in AstroLabs-people, for employee data such as reviews) from the template. For an Ops app, use app-builder's new-app instead. Use when the builder says "start a new app called X", "begin a new project called Y", "create a new app for Z", or otherwise wants to start something new from scratch. (If they already have a prototype, artifact or app, use adopt-existing-app.)
---

# new-app

Provision a fresh People app: a private repo from the People template, set up on
this machine, connected to its own Netlify site, with sign-in turned on. Assumes
set-up-my-computer is done.

Fixed for every People app: GitHub org **`AstroLabs-people`**, template
**`AstroLabs-people/app-starter`**, Netlify team **AstroLabs People**. If the Ops
app-builder is installed too and it isn't clear the app is for the People team,
ask which team it's for before creating anything.

## Steps

1. **Name it.** Turn what they said into a hyphenated, lowercase slug
   ("performance reviews" → `performance-reviews`). The repo name must be free in
   the org; if it's taken, add a short suffix (`-app`, `-people`, …). Never make the
   builder resolve a name collision.
2. **Create the repo from the template, then clone over HTTPS.** Avoid
   `gh … --clone` — it can fetch over SSH and hit the wrong account:
   `gh repo create "AstroLabs-people/<slug>" --template "AstroLabs-people/app-starter" --private`
   then `git clone "https://github.com/AstroLabs-people/<slug>.git" && cd <slug>`.
   (If the clone races the template copy and lands empty, just retry it.)
3. **Set up the machine for this app:** `bash scripts/bootstrap.sh`. It only asks
   for a name and email if set-up-my-computer hasn't set them; if it stops to ask,
   set them with `git config --global` (their own name and work email) and run it
   again, rather than answering its prompt.
4. **Connect the Netlify site** (no prompts; the same on Windows and Mac):
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/connect-netlify.sh" <slug> <site-name>
   ```
   It makes the site in the People team, links this folder to it straight away,
   registers a read-only deploy key, attaches the repo with Netlify's Next.js runtime,
   adds the GitHub webhook that makes previews happen, and adds build-status hooks.
   It ends with `status=connected` and the site's `site_url`.
   - **Exit 5 — the site name is taken** (site names are unique across all of
     Netlify): run it again with a suffixed site name. Nothing was created.
   - **Exit 1 — something failed:** fix the cause, then **run the same command
     again**. It reuses the site this folder is linked to and skips finished steps,
     so it never makes a second site. If the message mentions admin access on the
     repo, say *"Your access needs a fix from your admin — I can't do that part."*
   - **Exception:** if the message says it *made the site but couldn't link this
     folder*, don't re-run (it couldn't record the site, so a re-run would make
     another). Stop and tell the builder their admin needs to finish connecting it,
     giving the site id from the message.

   Attaching the repo starts the first build; don't start another. It has no live
   sign-in yet, so the live address won't open until the admin adds the live codes —
   that's expected.
5. **Turn on sign-in.** Ask in plain words for the **two sign-in codes for testing**
   their admin made for this app (*"Paste the two sign-in codes your admin sent for
   this app — they start with pk_test_ and sk_test_."*), then:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/codes.sh" store-test '<pk_test_…>' '<sk_test_…>'
   ```
   It refuses anything that isn't a test code (a live code never goes on previews),
   stores them for local runs and previews only, and checks they saved. If it refuses,
   ask again.

   Then approve the builder's own work email (`git config --global user.email`) on
   the test list and switch that list on:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/access.sh" approve test <their email>
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/access.sh" lock test
   ```
   (see **who-can-get-in** for what `lock` reports). If the builder doesn't have the
   test codes yet, skip this step and say: *"Your admin still needs to set up sign-in
   for this app — once they send the two codes, you'll be able to open it."* Do it as
   soon as the codes arrive. The **live** codes come later from the admin, once the
   app has its real web address.
6. The first preview comes with the builder's first change ("save a preview").

## Reply

> "Your new app '<X>' is ready, and only approved people can sign in to it. Want to
> see it? Just say 'show me'."

Say "only approved people can sign in" only once `lock test` printed `locked=yes`. If
the sign-in codes haven't arrived yet, end with the "your admin still needs to set
up sign-in" line from step 5 instead.

## Never

- Never add a site password or make the app public — sign-in is the only way in.
- Never put test codes on the live app or live codes on previews.
- Never put a Netlify deploy token or any sign-in code into the repo.
- Never fall back to `netlify init` or its browser GitHub authorization — it grabs
  the builder's personal GitHub session.
- Never create the app outside `AstroLabs-people` or the AstroLabs People Netlify
  team.
- Never say "repo", "org", "template", "Clerk", "key" or "deploy" to the builder.
