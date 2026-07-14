---
name: adopt-existing-app
description: Bring an app the builder already started — built elsewhere (their own GitHub, VS Code, a local folder, even a single HTML file) — onto the platform. Use when they say "I already have an app", "continue the project I built before", "I built this in VS Code / on my own GitHub", "import/bring in my project", "pick up from here", "I've been working on this — can you take it over", or point you at an existing repo or folder — or hand you a built file/link and ask to publish or update it (e.g. "here's an index.html, make it live", "I have a dashboard already deployed", "keep it on the same link", "I put this on Netlify myself"). For a brand-new app, use new-app instead.
---

# adopt-existing-app

Make an app the builder already has into a first-class platform app: a private repo
in the **team org**, connected to Netlify (preview-per-PR, prod-on-merge), using the
platform's **managed database** — without throwing away their working code. Assumes
the one-time setup is done (see set-up-my-computer) and this machine is signed in as
the team account.

**Be conservative.** Preserve their working code; add the platform's wiring *around*
it — don't rewrite their app's features to fit the template. When something needs a
real judgment call (a stack you can't cleanly fit, data sitting in a private place),
stop and explain in plain words.

## Steps

1. **Find their app.** Ask in plain words: *"Where's the app now — a folder on your
   computer, or a link?"* Most often it's already **local** (they built it in VS Code) —
   have them right-click the folder → **Copy path**. It may also be on their **personal
   GitHub** (they download/clone it with their own login first; the team account can't
   read their private repos), or just **loose files / a single HTML page**. End with the
   code in one folder on this machine.

2. **Assess it and say it back in one sentence** (*"Looks like a Next.js app that stores
   data with Prisma"*). Note a few things:
   - **Framework:** Next.js (ideal — matches the platform) · another framework · plain
     static HTML.
   - **Data layer:** none · Drizzle (matches) · Prisma · something else.
   - **Where its data lives now:** nowhere · a local/personal database (it must move to
     the platform's managed DB — never ship pointing at their private database).
   - *Static HTML that needs to store data is a special case:* you can't bolt a database
     onto a static page. Treat it like **new-app** — start from the template and carry
     their content and look across — and tell them plainly that's what you're doing.
   - **Already live?** If it's already deployed on a Netlify link they want to keep (e.g.
     one already shared with the team), note it — in step 6 you'll reuse that exact site,
     not create a new one.

3. **Create the platform home — a private repo in the team org** (`$BUILDER_GH_ORG`),
   never their personal account:
   `gh repo create "$BUILDER_GH_ORG/<slug>" --private` (slug per new-app's naming rule).
   Point the local folder at it **over HTTPS** (avoid SSH/wrong-account): add the new
   repo as `origin` (rename any existing remote to `old`), then push their code —
   keeping their commit history if there is any. This team-org repo is now the canonical
   home; their personal copy can be left or deleted.

4. **Graft the platform wiring** so the four-phrase flow and Netlify work afterward.
   From the `app-starter` template (`$BUILDER_GH_ORG/app-starter`), bring over the
   connective files their app is missing — *adapting, not clobbering their app code*:
   - `netlify.toml` (build config), `.github/workflows/checks.yml` (checks-only CI),
     `.nvmrc`, a framework-appropriate `.gitignore`,
   - `CLAUDE.md` (so the orchestrator + skills apply to this app afterward) and
     `scripts/bootstrap.sh`.
   Then `npm install` and confirm it **builds** (`npm run build`); fix config/version
   mismatches (scripts, Node version, lockfile) — not their features. (If it's not
   Next.js, Netlify still auto-detects most frameworks; only the managed-DB pattern
   below assumes Next.js API routes — flag it if they need data and aren't on Next.)

5. **Put the data on the platform's managed database** (Netlify DB / Neon). Prefer the
   platform convention but keep their working ORM rather than risk a rewrite:
   - **None or Drizzle:** use the template's `@netlify/database` + Drizzle, migrations in
     `netlify/database/migrations/` (auto-applied on deploy).
   - **Prisma:** keep Prisma — point its `DATABASE_URL` at the **Netlify DB** connection,
     and wire `prisma generate && prisma migrate deploy` into the Netlify build command
     (`netlify.toml`) so migrations apply on deploy. Note in the app's `CLAUDE.md` that
     this app uses Prisma, not Drizzle.
   - Either way: **never ship connected to a local/personal database.** Recreate their
     schema on the provisioned DB; if they have real data to bring across, ask first.

6. **Connect Netlify.** Seed the team GitHub token into Netlify's config first (see the
   **new-app** skill for the seed-token recipe + the org's OAuth-App-restriction caveat —
   always the seeded token, never the browser path), then run `netlify init`. Two cases:
   - **Already deployed on a Netlify link they want to keep** (common — e.g. a dashboard
     link already shared with the team): choose **"Connect to an existing project"** (the
     default top menu item — do *not* move down) and pick their existing site. This wires
     the repo's CI/CD to that same site, so the **URL is preserved — no duplicate.** The
     old version stays live until they say "make it live"; previews get their own links.
     (Requires the existing site to be on the platform Netlify team — see SETUP.md.)
   - **No existing site (or a new URL is fine):** choose **"Create & configure a new
     project"** (down one), the team, a unique name — as in new-app.
   The database provisions on the first deploy. Then **protect it by default** — set the
   site's Netlify password protection (see **make-it-private**) so the live site *and* its
   previews need a password, and give the builder the password. Public is an explicit
   opt-out.

7. **Confirm and hand back.** Get it running ("show me"), then report in plain words what
   you adopted and what — if anything — you changed.

## Reply

> "Done — your app '<X>' is now set up like the others: saved safely in one place, with
> its own database, ready to preview or put live. Want to see it? Just say 'show me'."

## Never

- Never leave the app on the builder's personal GitHub — the platform copy lives in the
  team org.
- Never ship the app pointing at a local or personal database — move it to the
  provisioned platform database.
- Never rewrite their features or silently change behavior to fit the template — graft
  the wiring around their working code, and ask when there's a real choice.
- Never use `netlify init`'s browser GitHub authorization (see new-app) — always the
  seeded team token.
- Never solve "publish/update this existing thing" with a hand-rolled manual deploy (a
  raw Netlify API call, a local script, a one-off upload) — this org ships apps through
  app-builder. Bring it onto the platform (adopt) and publish via make-it-live, so
  previews, rollback, and the live version stay authoritative.
- Never say "repo", "org", "ORM", "migration", or "deploy" to the builder.
