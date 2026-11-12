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
   PK=$(netlify env:get NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY --context production)
   SK=$(netlify env:get CLERK_SECRET_KEY --context production)
   [[ $PK == pk_live_* && $SK == sk_live_* ]] \
     || { echo "live sign-in not ready — stop, don't publish" >&2; exit 1; }
   ```
   If it fails, stop and say: *"The live sign-in isn't set up yet — your admin needs
   to finish it (it needs the app's real web address). Your preview keeps working
   in the meantime."* Never publish with test codes, and never publish without sign-in.
3. **Check it's safe to publish.** There must be an open preview pull request and
   its checks must be green. Never publish a change whose preview didn't build.
4. **Publish.** Merge the preview pull request into `main`. Netlify deploys `main`
   to the live app automatically — wait for that production deploy to finish and
   **confirm it succeeded** (its state is `ready` for the merged version). Any
   forward-only data change applies as part of this step. If the deploy failed,
   don't say it's live: the previous version is still up — explain the reason in one
   plain sentence and offer to fix it.
5. **Make sure someone can get in.** If the live list is empty (first time live),
   approve the builder's own work email with **who-can-get-in**, and tell them they
   can approve others the same way.

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
