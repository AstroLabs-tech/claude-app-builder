---
name: adopt-existing-app
description: Turn something the builder already made into a real People app — most often a Claude artifact or prototype (a single HTML file with sample data), or an app built elsewhere (their own GitHub, VS Code, a folder). Use when they say "I have a prototype", "I made this as an artifact", "turn my prototype into a real app", "I already have an app", "continue the project I built before", "here's my HTML", or point you at a file, folder or repo. For a brand-new app, use new-app instead.
---

# adopt-existing-app

Make what the builder already has into a first-class People app: a private repo in
**`AstroLabs-people`**, connected to the **AstroLabs People** Netlify team, with
sign-in for approved people, its data in the platform's managed database, and
**who-can-see-what enforced on the server**. Assumes set-up-my-computer is done.

## Steps

1. **Find it.** Ask in plain words: *"Where's your prototype or app — a file on your
   computer, a folder, or a link?"* For a **Claude artifact**, ask them to download it
   (the artifact's menu → Download) and tell you where the file is; you need the actual
   file, not a screenshot. Code on their personal GitHub: they download it with their
   own login first. End with everything in one folder on this machine.

2. **Read it and say back what it is in one or two sentences** (*"A prototype of a
   review app: employees, managers, People Team and Heads of BU each get their own
   screens; it keeps everything in your browser with sample people."*). Note:
   - **Kind:** a prototype/artifact (one HTML file, sample data, saves to the browser)
     · a Next.js app (matches the platform) · another framework.
   - **Who-sees-what rules:** prototypes usually only *hide* things on screen — note
     every rule you find (who sees which screen, which fields, at which stage).
   - **Its plan, if it has one:** a "hand-off", "spec" or "data model" section is gold —
     use it as the plan.
   - **Data:** sample data only, or real data somewhere (a sheet, a personal database).
   - **Anything that calls an outside service** (for example an AI check that ran on the
     viewer's own Claude account inside the artifact) — that can't work in a real app as
     is; flag it.

3. **Prototype or artifact → rebuild on the People template.** You can't put a
   prototype that keeps data in the browser on the internet as is. Follow **new-app**
   steps 1–5 (repo from `AstroLabs-people/app-starter`, Netlify, sign-in), then carry
   the prototype across **in slices**, saying the plan back first in plain words
   (e.g. *"First sign-in and each person's home screen, then the self-assessment, then
   the manager's part…"*). For each slice:
   - **Keep the look and the words** — screens, labels, flow, scoring rules.
   - **Replace sample data and browser storage with the database** (tables in
     `db/schema.ts`, migrations applied on publish).
   - **Replace "pick a persona / acting as" with real sign-in:** who someone is comes
     only from `getViewer()`; their role comes from the approved source (for example
     the master sheet), never from a switch in the screen.
   - **Move every who-sees-what rule to the server** (template `CLAUDE.md` → "Who can see
     what"): the server query only returns what this person may see, and every action
     checks they may take it at that stage. Before finishing a slice, say in one plain
     sentence who can see it and check the code matches.
   - **Outside services** (AI, email): leave them out or behind a simple switch until
     the builder confirms the service is approved for People data, then wire it with
     **store-secret**.
   Show each slice with "show me" before starting the next.

4. **An app that already runs elsewhere (not a prototype) → bring it over.** Only a
   **Next.js (App Router) app** can come over as is, because the sign-in only runs
   inside Next.js. Rebuild any other framework on the template, as in step 3.
   For a Next.js app, first, **locally**, graft the platform wiring from
   `AstroLabs-people/app-starter` around their code:
   `netlify.toml`, `.github/workflows/checks.yml`, `.nvmrc`, `.gitignore`, `CLAUDE.md`,
   `scripts/bootstrap.sh`, and the sign-in (`middleware.ts`, `lib/viewer.ts`,
   `app/sign-in`, `app/sign-up`, the provider in the root layout). Keep their working
   features; fix config, not features. Check its who-sees-what rules run on the
   server, as in step 3, and that it builds.
   - **Prove sign-in guards everything.** Run it with the two test codes the admin
     sent, passed on the command line the way **show-me** does, never saved to a
     file. While signed out, every page must send you to sign-in (307) and every
     API route must refuse (401/404).
   - **Data:** same as step 3. Tables go in `db/schema.ts` and are applied on
     publish. Real data comes only from the approved source, and only once sign-in
     and the server rules are in place (step 5).
   - **Outside services** the app already calls (AI, email, …): switch them off, or
     put them behind a simple switch, until the builder confirms the service is
     approved for People data, as in step 3.
   - **Only then** create `gh repo create "AstroLabs-people/<slug>" --private` and
     push a **clean start, not the old history**: earlier versions can hold employee
     data, keys, or a version without sign-in.
     ```bash
     set -e
     if [ -d .git ]; then
       git remote -v        # look before changing anything
       if git remote get-url origin >/dev/null 2>&1; then git remote rename origin "old-$(date +%Y%m%d%H%M%S)"; fi
       git checkout --orphan people-main
       git read-tree --empty   # start from an empty index so .gitignore applies to every file
     else
       git init -q -b people-main
     fi
     git add -A
     git diff --cached --name-only
     ```
     Read that file list. Anything that looks like keys or data (`.env*`, exports,
     `.csv` / `.xlsx`, database dumps) comes out first: `git rm --cached <file>`, and
     add it to `.gitignore`. Then:
     ```bash
     set -e
     NEW="https://github.com/AstroLabs-people/<slug>.git"
     git commit -q -m "Start <app> on the People platform"
     git remote add origin "$NEW"
     [ "$(git remote get-url origin)" = "$NEW" ] || { echo "wrong place — stop" >&2; exit 1; }
     git push -u origin people-main:main
     ```
     Never push the old branches or tags. Then connect Netlify and sign-in as in
     **new-app** steps 4–5.

5. **Data:** never ship pointing at a personal database or a personal copy of a
   spreadsheet. Real employee data comes in only from the source the builder confirms
   is approved, and only after sign-in and the server-side rules are in place.

6. **Confirm and hand back.** Get it running ("show me"), then say in plain words what
   you carried over, what you changed, and anything left open (for example "the AI
   check is switched off until it's approved").

## Reply

> "Done — '<X>' is now a real app: saved safely in one place, with its own database,
> and only approved people can sign in. Want to see it? Just say 'show me'."

## Never

- Never put a prototype online as is — a prototype that keeps data in the browser or
  only hides things on screen is not safe for employee data.
- Never decide who someone is or what they may see from anything the browser sends.
- Never leave the app on the builder's personal GitHub, and never create it outside
  `AstroLabs-people` / the AstroLabs People Netlify team.
- Never add a site password or make the app public.
- Never solve "publish this" with a hand-rolled upload or a raw Netlify call — publish
  through make-it-live.
- Never say "repo", "org", "migration", "server", "API" or "deploy" to the builder.
