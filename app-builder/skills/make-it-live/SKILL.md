---
name: make-it-live
description: Promote the previewed version to the builder's real site. Use whenever they say "make it live", "publish", "publish it", "ship it", "go live", or otherwise want the latest version on their real site. This is the ONLY action that asks for confirmation first.
---

# make-it-live

Publish the previewed version to the live site. This is the one action that
**always confirms first**.

> **Ops Hub exception.** In `AstroLabs-ops/astrolabs-cpr`, "make it live" means
> adding the **module** the builder is on into the main app — so the change lands in
> a shared app other people are using. Differences, all in **work-on-a-module**:
> confirm in those terms (*"this will add your <module> changes into the main app at
> https://astrolabs-cpr.netlify.app, which the whole team uses"*); apply the
> **stored-data rule** before publishing if anything under `db/` changed; and **skip
> step 4 entirely** — the hub is protected by AstroLabs Google sign-in inside the
> app, so it must never get a site password. The closing reply changes too: *"Done —
> your <module> changes are in the main app now at https://astrolabs-cpr.netlify.app.
> Anyone at AstroLabs can open it with their work Google account."* — never
> "password-protected", which isn't true here. Otherwise follow the steps below.

## Steps

1. **Confirm — every time.** Ask, and wait for a yes:
   > "This will update your real site at <live-url> with the latest version. Want me
   > to go ahead?"
2. **Check it's safe to publish.** There must be an open preview pull request and
   its checks must be green. Never publish a change whose preview didn't build.
   (On the Ops Hub, open the pull request from the module into `main` at this point,
   and wait for its checks — the module's own link builds don't gate publishing.)
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
- Never put a site password on the Ops Hub — it's already gated by AstroLabs Google
  sign-in inside the app, and a second gate just locks the team out.
- Never say "merge", "main", or "deploy" to the builder.
- Never tell the builder to log into Netlify.
