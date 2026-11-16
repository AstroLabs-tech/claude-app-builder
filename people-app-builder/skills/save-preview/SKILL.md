---
name: save-preview
description: Publish a private preview (behind sign-in) of the current app without touching the live site. Use whenever the builder says "save a preview", "make a link I can share", "I want to show someone", "put it somewhere I can check", or otherwise wants a link they can send around. Does NOT change their live site.
---

# save-preview

Save the current work, put it up, and hand back the shareable preview link that
Netlify builds for the open pull request. This never touches the live site. The
plugin's scripts do the risky parts; run them inside the app's folder:
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/<script>"`.

## Steps

1. **Check for someone else's work in progress:** `wip-check.sh`. Everyone shares one
   GitHub login, so it looks at who wrote the changes (ignoring Claude's co-author
   line and this builder's own addresses). Exit 7 with `other=<email>` lines means
   someone else has unpublished changes: ask before continuing — *"Heads up — Sam
   already has a change in progress on this app. Want to build on top of theirs, or
   wait?"* (One owner at a time per app.) It also prints `pr=<n>` if a preview is open.
2. **Move onto the working line:** `preview-branch.sh`. It switches to `preview`
   (carrying unsaved changes along), brings it up to date with GitHub's copy and with
   anything newer on the live line, and prints `changes=yes|no` and `waiting=<n>`
   (saved changes not on GitHub yet). Exit 7 means the changes clash: stop and
   explain plainly; nothing is left half-merged. **Don't say any of these words to
   the builder.**
3. **Save the work.** If `changes=yes`, stage everything and commit with a short,
   plain message describing what changed (e.g. "Add a contact form"). The builder's
   name is the author; the `Co-Authored-By: Claude` trailer stays on. If
   `changes=no` and `waiting=0`:
   - a preview is already open (`pr=<n>` in step 1) → run step 4, then skip to
     step 6 and re-share its link;
   - no open preview → say *"There's nothing new to preview yet — it's the same as
     your live app. Tell me what to change first."* and stop.
4. **Make sure only approved testers can open it:** `access.sh lock test` (see
   **who-can-get-in**). Exit 3: stop and say the admin needs to finish setting up
   sign-in for this app. Exit 4 or 1: stop before putting anything up and sort it out
   with the builder first.
5. **Push `preview` and open or update the pull request** into `main`
   (`gh pr create` if none is open; an existing one updates itself on push).
6. **Get the preview link.** Netlify builds a deploy preview for that pull request.
   Read its URL from the PR's Netlify status (`gh pr view --json statusCheckRollup`),
   or fall back to `https://deploy-preview-<PR-number>--<site-name>.netlify.app`.
   **Wait until that Netlify check has finished** before sharing — don't hand over a
   link that's still building.

   If no preview appears within a few minutes, run `held-build.sh <PR-number>`. Exit 9
   (`state=pending_review`) means Netlify doesn't know this person's GitHub sign-in
   yet. That happens once per person, on their first preview, and only an admin can
   clear it. Tell the builder: *"Your first preview needs a one-time OK from your
   admin before it can be built. Once they've approved it, it builds by itself — say
   'save a preview' again and I'll give you the link."* For the admin, give this exact
   path: the app in Netlify → **Deploys** → the held preview → **Further action
   required** → **Approve and match with existing team member** → pick the builder.
   Never suggest **Reject**: after a reject, every later preview from that person
   needs approval again.
7. If the build failed, don't share a broken link — read the reason, explain it in
   one plain sentence, and offer to fix it.

## Reply

> "Saved! Here's your preview: <url>. Only people on your test list can sign in to it
> (say *"let Sara test it"* to add someone) — and it won't change your live app."

## Never

- Never say "commit", "branch", "push", "pull request", or "deploy".
- Never merge into `main` or touch the live site — that's "make it live".
- Never share the link before the preview has finished building.
