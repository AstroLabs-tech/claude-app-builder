---
name: make-it-live
description: Promote the previewed version to the builder's real site. Use whenever they say "make it live", "publish", "publish it", "ship it", "go live", or otherwise want the latest version on their real site. This is the ONLY action that asks for confirmation first.
---

# make-it-live

Publish the previewed version to the live site. This is the one action that
**always confirms first**.

## Steps

1. **Confirm — every time.** Ask, and wait for a yes:
   > "This will update your real site at <live-url> with the latest version. Want me
   > to go ahead?"
2. **Check it's safe to publish.** There must be an open preview pull request and
   its checks must be green. Never publish a change whose preview didn't build.
3. **Publish.** Merge the preview pull request into `main`. Netlify deploys `main`
   to the live site automatically — wait for that production deploy to finish.
   Any forward-only data change applies as part of this step.
4. **Protected-by-default cue.** The live site is **password-protected** (set when the
   app was created — see new-app / make-it-private). Remind them plainly:
   *"Your live link stays password-protected — only people with the password can open
   it. Say 'make it public' if you'd like anyone to open it."* If it somehow isn't
   protected yet, apply protection now (make-it-private) before sharing the link.

## Reply

> "Done — it's live now at <live-url> (password-protected)."

## Never

- Never skip the confirmation.
- Never publish when the preview's checks are red.
- Never make a live site public unless the builder explicitly asked — protected is the default.
- Never say "merge", "main", or "deploy" to the builder.
- Never tell the builder to log into Netlify.
