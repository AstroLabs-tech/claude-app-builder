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
4. **Connect the Netlify site — scripted, no prompts** (works the same on Windows
   and Mac). These are exactly the calls `netlify init` makes under the hood; doing
   them directly avoids its arrow-key menus, which can't be driven on Windows.
   If a GitHub step answers 404 or 403, the sign-in on this computer can't manage this
   app's settings. Say *"Your access needs a fix from your admin — I can't do that
   part,"* never a raw error.

   ```bash
   set -eo pipefail   # any failed call, even inside a pipe, stops everything after it
   SLUG=<slug>; NAME=<globally-unique site name>; REPO="AstroLabs-people/$SLUG"
   ACCT=$(netlify api listAccountsForUser | jq -r '.[] | select(.name=="AstroLabs People") | .slug' | tr -d '\r')
   [ -n "$ACCT" ] || { echo "not on the AstroLabs People team" >&2; exit 1; }
   # 1. the site, in the People team (on "name already taken", retry with a suffix)
   SITE_ID=$(netlify api createSiteInTeam --data "$(jq -n --arg a "$ACCT" --arg n "$NAME" '{account_slug:$a, body:{name:$n}}')" | jq -r .id | tr -d '\r')
   # 2. a read-only deploy key, registered on the repo
   KEY=$(netlify api createDeployKey)
   KEY_ID=$(jq -r .id <<<"$KEY" | tr -d '\r'); PUB=$(jq -r .public_key <<<"$KEY" | tr -d '\r')
   gh api -X POST "repos/$REPO/keys" -f title="Netlify Deploy Key" -f key="$PUB" -F read_only=true >/dev/null
   # 3. attach the repo and Netlify's Next.js runtime (without it every page is a 404);
   #    Netlify answers with the site's deploy hook URL
   REPO_ID=$(gh api "repos/$REPO" --jq .id)
   HOOK=$(netlify api updateSite --data "$(jq -n --arg s "$SITE_ID" --argjson rid "$REPO_ID" --arg k "$KEY_ID" --arg p "$REPO" \
     '{site_id:$s, body:{repo:{id:$rid, provider:"github", repo_path:$p, repo_branch:"main", allowed_branches:["main"], deploy_key_id:$k, cmd:"npm run build", dir:".next"}, plugins:[{package:"@netlify/plugin-nextjs"}]}}')" \
     | jq -r .deploy_hook | tr -d '\r')
   [ -n "$HOOK" ] && [ "$HOOK" != null ] || { echo "no deploy hook returned" >&2; exit 1; }
   # 4. GitHub tells Netlify about pushes and pull requests (this is what makes previews fire)
   gh api -X POST "repos/$REPO/hooks" -f name=web -f "config[url]=$HOOK" -f "config[content_type]=json" \
     -f "events[]=push" -f "events[]=pull_request" -f "events[]=delete" -F active=true >/dev/null
   # 5. Netlify reports build status back on GitHub
   for EV in deploy_created deploy_failed deploy_building; do
     netlify api createHookBySiteId --data "$(jq -n --arg s "$SITE_ID" --arg e "$EV" --arg t "$(gh auth token)" \
       '{site_id:$s, body:{type:"github_commit_status", event:$e, data:{access_token:$t}}}')" >/dev/null
   done
   # 6. link this folder to the site (attaching the repo in step 3 already started the first build)
   netlify link --id "$SITE_ID"
   ```
   Every call must succeed — stop at the first failure and explain it in one plain
   sentence. Don't start another build: step 3 already did. Confirm with
   `netlify status`, that the site's `build_settings.repo_path` is
   `AstroLabs-people/<slug>`, that the site's `plugins` include
   `@netlify/plugin-nextjs`, and that the first build in
   `netlify api listSiteBuilds --data '{"site_id":"…"}'` reaches `deploy_state: ready`.
   The first build has no live sign-in yet, so the live address won't open until the
   admin adds the live codes — that's expected.
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

   If you stored the test codes, put the builder's own work email on the approved list (the
   **who-can-get-in** skill, test list) so they can sign in to their own app, and
   **switch that list on** (who-can-get-in → *Switch the list on*). If it doesn't
   come back on, stop and say the admin needs to switch on the approved-list setting.
   With no test codes yet, skip both; do them as soon as the codes arrive.
6. The first preview comes with the builder's first change ("save a preview").

## Reply

> "Your new app '<X>' is ready, and only approved people can sign in to it. Want to
> see it? Just say 'show me'."

Say "only approved people can sign in" only once the test list came back on. If
the sign-in codes haven't arrived yet, end with the "your admin still needs to set
up sign-in" line from step 5 instead.

## Never

- Never add a site password or make the app public — sign-in is the only way in.
- Never put test codes on the live app or live codes on previews.
- Never put a Netlify deploy token or any sign-in code into the repo.
- Never fall back to `netlify init`'s browser GitHub authorization — it grabs the
  builder's personal GitHub session.
- Never create the app outside `AstroLabs-people` or the AstroLabs People Netlify
  team.
- Never say "repo", "org", "template", "Clerk", "key" or "deploy" to the builder.
