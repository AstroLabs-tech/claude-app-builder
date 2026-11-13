---
name: make-it-live
description: Promote the previewed version to the builder's real People app. Use whenever they say "make it live", "publish", "publish it", "ship it", "go live", or otherwise want the latest version on their real app. This is the ONLY action that asks for confirmation first.
---

# make-it-live

Publish the previewed version to the live app. This is the one action that
**always confirms first**.

## Steps

1. **Confirm — every time.** Ask, and wait for a yes:
   > "This will update your real app at <live-url> with the latest version. Want me
   > to go ahead?"
2. **Check the live sign-in is set up — and stop if it isn't.** A People app must
   never go live without its own live sign-in. Check, without printing the values,
   that the live codes exist and are live ones:
   ```bash
   set -o pipefail
   get() { netlify env:get "$1" --context production --json | jq -er --arg k "$1" '.[$k] // ""' | tr -d '\r'; }
   PK=$(get NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY) && SK=$(get CLERK_SECRET_KEY) \
     || { echo "couldn't read this app's settings — stop, don't publish" >&2; exit 1; }
   [[ $PK == pk_live_* && $SK == sk_live_* ]] \
     || { echo "live sign-in not ready — stop, don't publish" >&2; exit 1; }
   ```
   If it fails, stop and say: *"The live sign-in isn't set up yet — your admin needs
   to finish it (it needs the app's real web address). Your preview keeps working
   in the meantime."* Never publish with test codes, and never publish without sign-in.

   Then make sure someone can get in and nobody else can: if the live list is empty
   (first time live), approve the builder's own work email (**who-can-get-in**, live
   list), then **switch the live list on** (who-can-get-in → *Switch the list on*,
   `CTX=production`). If it doesn't come back on, stop — don't publish.
3. **Check it's safe to publish.** There must be an open preview pull request and
   its checks must be green. Never publish a change whose preview didn't build.
4. **Publish.** Merge the preview pull request into `main`. Netlify deploys `main`
   to the live app automatically — wait for that production deploy to finish and
   **confirm it succeeded and is the one published**: its state is `ready`, and the
   site's `published_deploy.commit_ref` (`netlify api getSite`) is the merged
   commit. Ready but not published means publishing is paused on the site: say
   the new version is ready but your admin has paused publishing, and never say
   it's live. Any forward-only data change applies as part of this step. If the
   deploy failed, don't say it's live: the previous version is still up — explain
   the reason in one plain sentence and offer to fix it. If no deploy appears, check
   for a build held at `pending_review` (see **save-preview** step 6): it needs the
   same one-time admin OK, and the previous version stays up until then.
5. **First time live:** tell them they can approve others the same way.

## Reply

> "Done — it's live at <live-url>. Only people on your approved list can sign in
> (say *"let Sara in"* to add someone)."

## Never

- Never skip the confirmation.
- Never publish when the preview's checks are red.
- Never publish without live sign-in codes, and never put a site password on the
  app or make it public.
- Never say "merge", "main", "deploy", "Clerk" or "key" to the builder.
- Never tell the builder to log into Netlify.
