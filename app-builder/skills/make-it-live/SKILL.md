---
name: make-it-live
description: Promote the previewed version to the builder's real, public site. Use whenever they say "make it live", "publish", "publish it", "ship it", "go live", or otherwise want the latest version on their real site. This is the ONLY action that asks for confirmation first.
---

# make-it-live

Publish the previewed version to the live site. This is the one action that
**always confirms first**.

## Steps

1. **Confirm — every time.** Ask, and wait for a yes:
   > "This will update your live site at <live-url> so anyone can see the latest
   > version. Want me to go ahead?"
2. **Check it's safe to publish.** There must be an open preview pull request and
   its checks must be green. Never publish a change whose preview didn't build.
3. **Publish.** Merge the preview pull request into `main`. Netlify deploys `main`
   to the live site automatically — wait for that production deploy to finish.
   Any forward-only data change applies as part of this step.
4. **Public-by-default cue.** The first time an app goes live (or any time it
   looks like it holds private information), add one plain line:
   *"Note: anyone with this link can open it — say the word if you'd like it
   limited to your team."*

## Reply

> "Done — it's live now at <live-url>."

## Never

- Never skip the confirmation.
- Never publish when the preview's checks are red.
- Never say "merge", "main", or "deploy" to the builder.
- Never tell the builder to log into Netlify.
