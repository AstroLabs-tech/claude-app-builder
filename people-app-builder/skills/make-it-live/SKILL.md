---
name: make-it-live
description: Promote the previewed version to the builder's real People app. Use whenever they say "make it live", "publish", "publish it", "ship it", "go live", or otherwise want the latest version on their real app. This is the ONLY action that asks for confirmation first.
---

# make-it-live

Publish the previewed version to the live app. This is the one action that
**always confirms first**. The plugin's scripts do the risky parts; run them inside
the app's folder: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/<script>"`.

## Steps

1. **Confirm — every time.** Ask, and wait for a yes:
   > "This will update your real app at <live-url> with the latest version. Want me
   > to go ahead?"
2. **Check the live sign-in is set up:** `codes.sh check-live`. A People app must
   never go live without its own live sign-in. Exit 3: stop and say *"The live
   sign-in isn't set up yet — your admin needs to finish it (it needs the app's real
   web address). Your preview keeps working in the meantime."*
3. **Check it's safe to publish:** `publish.sh check <PR-number>` (the open preview).
   It reads the preview's current version and every check on it in one go, requires
   all of them to have passed **and** Netlify's own preview to have built, and prints
   `head=<sha>`; keep it for step 5. Exit 6: still checking or building, so try again
   shortly. Exit 9: Netlify is holding the preview for the one-time admin OK (see
   **save-preview** step 6). Exit 1: the preview didn't pass; never publish it. If
   this stops you, nothing has been changed.
4. **Make sure someone can get in and nobody else can — every time.** Run
   `access.sh list live`. If it shows `count=0`, note that (step 6 needs it), approve
   the builder's own work email (`git config --global user.email`) with
   `access.sh approve live <email>`, and tell them you've added them so they can open
   it. Then `access.sh lock live` (see **who-can-get-in**). If it doesn't print
   `locked=yes`, stop and don't publish; the live list may already have changed (the
   builder approved, the setting switched on), so say what was done.
5. **Publish:** `publish.sh merge <PR-number> <head>` merges exactly the version that
   was checked (a normal merge, so each live version maps to a commit on `main`) and
   prints `merged=yes`. Exit 7: someone saved changes since the check, so go back to
   step 3. Then `publish.sh status <PR-number>` until it prints `live=<url>`:
   - exit 6: still building (or GitHub is still recording the publish); check again
     in a little while;
   - exit 8: the new version is ready, but publishing is paused on this app; say so,
     and never say it's live;
   - exit 9: Netlify is holding it for the same one-time admin OK as a first preview
     (see **save-preview** step 6); the previous version stays up until then;
   - exit 1: it didn't build; the previous version is still up. Explain the reason in
     one plain sentence and offer to fix it.

   Any forward-only data change applies as part of this step.
6. **If the live list was empty in step 4:** tell them that people they approved for
   testing aren't on the live list yet, and that they can approve anyone for the
   live app the same way (*"let Sara in"*).

## Reply

> "Done — it's live at <live-url>. Only people on your approved list can sign in
> (say *"let Sara in"* to add someone)."

## Never

- Never skip the confirmation.
- Never publish when the preview's checks are red, or merge any other way than
  `publish.sh merge`.
- Never publish without live sign-in codes, and never put a site password on the
  app or make it public.
- Never say "merge", "main", "deploy", "Clerk" or "key" to the builder.
- Never tell the builder to log into Netlify.
