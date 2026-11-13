---
name: save-preview
description: Publish a private preview (behind sign-in) of the current app without touching the live site. Use whenever the builder says "save a preview", "make a link I can share", "I want to show someone", "put it somewhere I can check", or otherwise wants a link they can send around. Does NOT change their live site.
---

# save-preview

Commit the current work, push it, and hand back the shareable preview link that
Netlify builds for the open pull request. This never touches the live site.


## Steps

1. **Check for someone else's work in progress.** Everyone shares one GitHub login,
   so look at who wrote the changes, not who opened the pull request:
   `gh pr list --head preview --state open --json number,commits --jq '.[].commits[].authors[].email'`.
   Compare lowercased, and ignore Claude's co-author address
   (`noreply@anthropic.com`, on every change). If any other email isn't this
   builder's (`git config --global user.email`),
   say so plainly and ask before continuing:
   *"Heads up — Sam already has a change in progress on this app. Want to build on
   top of theirs, or wait?"* (One owner at a time per app.)
2. **Move onto the working line before saving.** Unsaved changes come along when
   you switch. After `git fetch origin`: `git switch preview` if it exists here,
   `git switch -c preview --track origin/preview` if it exists only on GitHub,
   otherwise `git switch -c preview origin/main`. If it exists both here and on
   GitHub, bring this copy up to date with `git merge --ff-only origin/preview`.
   Then bring in anything newer on the live line: `git merge --no-edit origin/main`
   (a normal merge, never a rebase). If the switch or a merge refuses because the
   changes clash, stop and explain plainly. **Don't say any of these words to the
   builder.**
3. **Save the work.** Stage everything and commit with a short, plain message
   describing what changed (e.g. "Add a contact form"). The builder's name is the
   author; the `Co-Authored-By: Claude` trailer stays on. If nothing changed
   **and** nothing saved here is still waiting to go up (`git log --oneline
   origin/preview..preview` is empty, or with no `preview` on GitHub yet,
   `git log --oneline origin/main..preview` is empty):
   - an open preview pull request already exists → run step 4 (the list check),
     then skip to step 6 and re-share its link;
   - no open preview → say *"There's nothing new to preview yet — it's the same as
     your live app. Tell me what to change first."* and stop.

   If something saved is still waiting to go up (say, after a failed push), carry
   on to step 4.
4. **Make sure only approved testers can open it.** Run who-can-get-in → *Switch
   the list on* for the test list (`CTX=dev`), including its account check. If
   there are no test codes, stop and say the admin needs to finish setting up
   sign-in for this app. If the list doesn't come back on, or unapproved accounts
   are left, stop before pushing and sort that out with the builder first.
5. **Push `preview` and open or update the pull request** into `main`
   (`gh pr create` if none is open; an existing one updates itself on push).
6. **Get the preview link.** Netlify builds a deploy preview for that PR
   automatically. Read its URL from the PR's Netlify status (e.g.
   `gh pr view --json statusCheckRollup` or the commit status), or fall back to
   the pattern `https://deploy-preview-<PR-number>--<site-name>.netlify.app`.
   **Wait until that Netlify check has finished** before sharing — don't hand over
   a link that's still building.
   If no preview appears within a few minutes, check whether Netlify is **holding**
   it. A held build never shows in the normal list of deploys, only in the builds:
   ```bash
   SITE_ID=$(jq -er .siteId .netlify/state.json | tr -d '\r')
   netlify api listSiteBuilds --data "{\"site_id\":\"$SITE_ID\"}" \
     | jq -r --arg p "pull/<PR-number>/head" '[.[] | select(.sha==$p)][0].deploy_state' | tr -d '\r'
   ```
   `pending_review` means Netlify doesn't yet know this person's GitHub sign-in. It
   happens once per person, on their first preview. Only an admin can clear it, so
   tell the builder: *"Your first preview needs a one-time OK from your admin before
   it can be built. Once they've approved it, it builds by itself — say 'save a
   preview' again and I'll give you the link."* For the admin, give this exact
   path: the app in Netlify → **Deploys** → the held preview → **Further action
   required** → **Approve and match with existing team member** → pick the builder.
   Never suggest **Reject**: after a reject, every later preview from that person
   needs approval again.
7. If the build failed, don't share a broken link — read the reason, explain it
   in one plain sentence, and offer to fix it.

## Reply

> "Saved! Here's your preview: <url>. Only people on your test list can sign in to it
> (say *"let Sara test it"* to add someone) — and it won't change your live app."

## Never

- Never say "commit", "branch", "push", "pull request", or "deploy".
- Never merge into `main` or touch the live site — that's "make it live".
- Never share the link before the preview has finished building.
