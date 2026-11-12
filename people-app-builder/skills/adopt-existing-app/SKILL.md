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

4. **An app that already runs elsewhere (not a prototype) → bring it over.** Create
   `gh repo create "AstroLabs-people/<slug>" --private`, point the folder at it over
   HTTPS (rename any existing remote to `old`), push their code with its history, then
   graft the platform wiring from `AstroLabs-people/app-starter` around their code:
   `netlify.toml`, `.github/workflows/checks.yml`, `.nvmrc`, `.gitignore`, `CLAUDE.md`,
   `scripts/bootstrap.sh`, and the sign-in (`middleware.ts`, `lib/viewer.ts`,
   `app/sign-in`, `app/sign-up`, the provider in the root layout). Keep their working
   features; fix config, not features. Then check its who-sees-what rules run on the
   server, as in step 3. Connect Netlify and sign-in as in **new-app** steps 4–5.

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
