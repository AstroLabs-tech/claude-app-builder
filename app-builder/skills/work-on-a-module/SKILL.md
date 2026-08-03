---
name: work-on-a-module
description: Work on one part ("module") of the AstroLabs Ops Hub without touching the rest of it, and add that part to the main app when it's ready. Use whenever the builder mentions a module or a part of the Ops Hub — "I'm updating the onboarding module", "which modules are there", "what parts are in the hub", "build a new module for X", "add my module to the main app", "put this in the main app" — or names a piece of the hub such as onboarding, community hub, licensing or portfolio. Only applies to the Ops Hub app.
---

# work-on-a-module

The **Ops Hub** is one app made of several parts. Each part — a *module* — is worked
on separately, and gets its own link to check before it goes into the main app.

**What is and isn't separate.** A module's *pages and behaviour* are separate: editing
one module's screens can't change another's. Its **stored data is not** — every module
shares one database and one change history, so saving records through a module link may
be writing the same data the live app uses, and a change to how data is stored can
affect other modules (see the stored-data rule). Never tell a builder a module is a
safe sandbox for data.

This applies to **one app only**: the repo `AstroLabs-ops/astrolabs-cpr`
(Netlify site `astrolabs-cpr`). Every other app is a single app with a single live
site — for those, ignore this skill entirely and use the normal
show-me / save-preview / make-it-live flow.

> Match the org too, not just the name. A different, retired repo called
> `AstroLabs-tech/astrolabs-cpr` also exists (it serves the old
> `alcustomerportfolio` site). Only `AstroLabs-ops/astrolabs-cpr` is the live hub.

## What counts as a module

A module is a working line that Netlify gives a **permanent link** to, because it's
listed in the site's `build_settings.allowed_branches`. Read the real list — never
guess from names — and **drop the production line** (`build_settings.repo_branch`,
currently `main`): that one is the main app itself, not a module.

**Fail closed** — a failed API call returns nothing, which looks exactly like "this hub
has no modules". Never act on an unchecked read: you'd offer to create a module that
already exists, or tell a builder theirs is gone.

```bash
SITE=astrolabs-cpr.netlify.app
S=$(netlify api getSite --data "{\"site_id\":\"$SITE\"}") \
  || { echo "couldn't reach the site — stop here, don't guess" >&2; exit 1; }
jq -e '.build_settings.repo_branch and
       (.build_settings.allowed_branches | type == "array" and length > 0)' <<<"$S" >/dev/null \
  || { echo "site settings look wrong — stop here, don't guess" >&2; exit 1; }
jq -r '.build_settings as $b | $b.allowed_branches[] | select(. != $b.repo_branch)' <<<"$S"
```

Anything not in that list is ordinary in-progress work, not a module. Its link is a
temporary one tied to an open change, so don't present it as a module.

A module's link is `https://<module>--astrolabs-cpr.netlify.app`; the **main app** is
`https://astrolabs-cpr.netlify.app` (never `main--…`). That pattern only holds for
plain lowercase-and-hyphen names, so keep module names to that shape — and open the
link once to check it resolves before handing it to a builder.

## Steps

1. **Work out which module they mean.** If it's obvious from what they said, use it.
   If not, **ask — never make them recall a name**: list the modules in plain words
   with their links and let them pick. If they describe something that isn't a module
   yet, offer to start a new one.
2. **Get onto it.** Make sure the hub is on this machine (clone over HTTPS if not —
   see new-app step 2), then switch to that module and bring it up to date with the
   main app. If they have unsaved work on a different module, say so plainly and ask
   before switching — don't silently carry or discard their changes.
3. **Starting a new module?** Create it from the current main app as a
   lowercase-hyphenated name, then **add it to the site's permanent-link list in the
   same step** — a new module that isn't on the list silently gets no link, and the
   builder is left waiting for one that will never appear. Because two people can set
   up modules at once and this is a read-then-write, **re-read after writing and retry
   if it didn't stick** (a simultaneous setup can otherwise drop one of them):

   ```bash
   SITE=astrolabs-cpr.netlify.app; MOD=<module>
   for attempt in 1 2 3; do
     CUR=$(netlify api getSite --data "{\"site_id\":\"$SITE\"}" \
       | jq -c '.build_settings.allowed_branches // empty')
     [ -n "$CUR" ] || { echo "couldn't read the link list (try $attempt)" >&2; continue; }
     # append only if absent — keeps the existing order untouched
     WANT=$(jq -cn --argjson cur "$CUR" --arg b "$MOD" \
       '$cur + (if $cur | index($b) then [] else [$b] end)')
     netlify api updateSite \
       --data "{\"site_id\":\"$SITE\",\"build_settings\":{\"allowed_branches\":$WANT}}" >/dev/null
     GOT=$(netlify api getSite --data "{\"site_id\":\"$SITE\"}" \
       | jq -c '.build_settings.allowed_branches // empty')
     # every name we expected must still be there — a simultaneous setup can drop one
     jq -en --argjson w "$WANT" --argjson g "${GOT:-[]}" '($w - $g) | length == 0' >/dev/null \
       && { echo "link list confirmed: $GOT"; break; }
     [ "$attempt" = 3 ] && { echo "link list not updated after 3 tries" >&2; exit 1; }
   done
   ```
   The check is on the **whole** expected list, not just this module — if two people set
   up modules at the same moment, one write can drop the other's, and this re-adds it.
   If it still fails after three tries, stop and say so plainly — don't promise a link
   that won't exist.

   *(No cross-machine lock is possible here — builders work on their own laptops with no
   shared coordination point, and Netlify's API has no conditional update for this field.
   Detect-and-repair is the honest ceiling, and module creation is rare enough that it's
   proportionate.)*
4. **Bringing in an app they already have?** If what they want as a module already
   exists as its own app, this is a **move, not a rebuild** — do not start from
   scratch and do not create a separate repo or site for it (that's what
   adopt-existing-app does for standalone apps, and it's the wrong shape here).
   Start a new module per step 3, carry their working code into it, and reconcile only
   what has to change: shared layout/navigation, and their tables renamed to the
   module's own prefix so they can't collide with another module's. Treat those tables
   as a first data change under the stored-data rule.

   **Their existing records do not come across on their own.** Renaming tables into
   the hub creates *empty* ones — the old app's rows stay in the old app's separate
   database. So ask what's in there and say plainly what will happen: if the records
   matter, copy them across deliberately and check a few in the new module before it
   goes into the main app; if they're test data, confirm it's fine to start empty.
   Never let a builder assume their data followed the move (this is exactly how the
   onboarding module ended up showing 0% next to the old site's 71%).

   If their app is a different stack, or a static page that needs stored data, say
   plainly that this one does need rebuilding on the hub, and why.
5. **Then build as normal.** "show me" runs it on their machine; "save a preview"
   shares this module's link; "make it live" adds the module into the main app — and
   that step **always asks first**, because it lands in the app the whole team uses.
6. **If they changed how data is stored** (anything under `db/`), follow the
   **stored-data rule** below before the change goes into the main app.

## The stored-data rule (why this matters)

The hub's modules share one database, and its change-history files describe **the
whole database**, not just one module's part of it — each one records every table and
points back at the previous state. So if two modules each record a change on their
own line, both claim to follow the same previous state and neither knows about the
other's new tables. Once both go into the main app, the next change is generated
against only one of them, and the other module's tables look like they should be
deleted. Per-module table naming does **not** prevent this, and giving each module
its own database wouldn't either — it would just move the collision to the same
point.

**So: bring the main app into the module first, and only then record the data
change** — that way its history follows the latest state and includes every module's
tables. If a module already recorded a data change before the main app moved on,
re-record it on top of the updated main app rather than resolving the history files
by hand.

Never delete or edit a data-change file that has already gone live — the platform
refuses to deploy if one disappears, and that failure surfaces on someone else's
module.

## Reply

> "You're on the **<module>** module now. You can check it any time at
> <module-link>. The pages here are yours — editing them won't change anyone else's
> part of the app. Anything you *save* goes into the shared data the team uses, so
> treat records as real. When it's ready, say 'make it live' and I'll ask you to
> confirm before it goes into the main app."

## Never

- Never say "branch", "merge", "pull request", "commit", or "deploy" to the builder —
  say *module*, *the main app*, *your link*. (Understand those words if **they** use
  them; just don't introduce them.)
- Never apply this to any app other than `AstroLabs-ops/astrolabs-cpr` — every other
  app keeps the single-app flow.
- Never create a module without confirming it reached the site's permanent-link list.
- Never present an ordinary in-progress line, or the main app's own line, as a module.
- Never describe a module link as private, safe to experiment in, or separate from the
  team's data — it shares the hub's database.
- Never imply a moved app's existing records came with it unless they were actually
  copied and checked.
- Never put a password on the Ops Hub site — it's protected by AstroLabs Google
  sign-in inside the app, so a site password would be a second, confusing gate.
- Never guess the module list or a link — read both from the site.
