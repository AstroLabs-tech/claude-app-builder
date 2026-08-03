---
name: save-preview
description: Publish a private, shareable preview of the current app without touching the live site. Use whenever the builder says "save a preview", "make a link I can share", "I want to show someone", "put it somewhere I can check", or otherwise wants a link they can send around. Does NOT change their live site.
---

# save-preview

Commit the current work, push it, and hand back the shareable preview link that
Netlify builds for the open pull request. This never touches the live site.

> **Ops Hub exception** (`AstroLabs-ops/astrolabs-cpr`). The builder works on a
> *module*, which already has its own permanent link — see **work-on-a-module**.
> Every other app follows the steps below unchanged. On the hub:
>
> - **Step 1 applies per module, not per app.** Separate people working separate
>   modules at once is the whole point — only flag a clash on the **same** module.
> - **Skip steps 3–5.** Do **not** create or switch to a `preview` line (that would
>   take them off their own module) and do **not** open a pull request — publishing
>   does that later. Push the module's working line, wait for its build to succeed,
>   then hand back `https://<module>--astrolabs-cpr.netlify.app`. Step 6 still
>   applies: never share the link if the build failed.
> - **The reply is different.** The hub has no site password — it's gated by
>   AstroLabs Google sign-in inside the app. Say: *"Saved! Here's your module's link:
>   <url>. Anyone at AstroLabs can open it with their work Google account, and it
>   won't change the main app."* Never mention a password, and never ask them for one.
>   **Confirm that's still true before you say it** — same fail-closed check as
>   make-it-live's Ops Hub note. If a site password has appeared, don't hand over the
>   link describing sign-in that isn't what's guarding it; stop and report instead.
> - **Say what the link isn't.** It's a separate copy of the *pages*, not of the data —
>   anything they save through it goes into the same records the live app uses. Never
>   call it a safe place to experiment with data.

## Steps

1. **Check for someone else's work in progress.** If the app already has an open
   preview/PR from another person, say so plainly and ask before continuing:
   *"Heads up — Sam already has a change in progress on this app. Want to build on
   top of theirs, or wait?"* (One owner at a time per app.)
2. **Save the work.** Stage everything and commit with a short, plain message
   describing what changed (e.g. "Add a contact form"). The builder's name is the
   author; the `Co-Authored-By: Claude` trailer stays on. If nothing has changed
   since the last preview, skip ahead and just re-share the existing link.
3. **Push the working line.** Work on a branch named `preview` (create it from
   `main` if it doesn't exist) and push it. **Don't say any of these words to the
   builder.**
4. **Open or update the pull request** from `preview` into `main` (`gh pr create`
   if none is open; an existing one updates itself on push).
5. **Get the preview link.** Netlify builds a deploy preview for that PR
   automatically. Read its URL from the PR's Netlify status (e.g.
   `gh pr view --json statusCheckRollup` or the commit status), or fall back to
   the pattern `https://deploy-preview-<PR-number>--<site-name>.netlify.app`.
   **Wait until that Netlify check has finished** before sharing — don't hand over
   a link that's still building.
6. If the build failed, don't share a broken link — read the reason, explain it
   in one plain sentence, and offer to fix it.

## Reply

> "Saved! Here's your shareable preview: <url>. It's behind your app's password, so
> only people you give the password to can open it — and it won't change your live site."

## Never

- Never say "commit", "branch", "push", "pull request", or "deploy".
- Never merge into `main` or touch the live site — that's "make it live".
- Never share the link before the preview has finished building.
