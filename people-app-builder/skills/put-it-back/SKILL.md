---
name: put-it-back
description: Roll the live app back to the previous working version. Use whenever the builder says "put it back", "undo the live version", "go back to how it was", "revert it", or otherwise wants to undo what's currently live. Instant, and it leaves the project history intact.
---

# put-it-back

Roll the live app back to the previous successful version by republishing it on
Netlify — done entirely through the tools, never a dashboard.

## Steps

1. Find the previous successful **production** deploy (Netlify keeps every past
   deploy). List them, then pick the one before the current live version —
   e.g. `netlify api listSiteDeploys` to find it, then `netlify api
   restoreSiteDeploy` (or the Netlify MCP rollback tool) to republish it.
2. Republish that deploy as the live site and wait for it to take effect.
3. **Keep the problem from coming back.** Rolling back doesn't stop auto
   publishing, and `main` still holds the faulty version, so the next "make it live"
   would publish it again. Straight away, add the undo on top of the working line
   as one new change (never rewrite history):
   ```bash
   GOOD=<commit_ref of the deploy you just republished>
   git fetch origin
   # get onto `preview` exactly as save-preview step 2 does (GitHub's copy if it has one)
   git diff --binary origin/main "$GOOD" | git apply --index --3way
   git commit -m "Put back the version from before <the problem, in plain words>"
   git push -u origin preview
   ```
   Then open or update the preview pull request as **save-preview** does. The diff
   undoes exactly what `main` gained after the good version and leaves any
   unpublished work on `preview` alone. If it doesn't apply cleanly, stop: the live
   app is already back, so say that, and that the undo still needs saving before
   the next "make it live". To bring a feature back later, fix it forward on the
   preview.

## Reply

> "Rolled back — your live app is the way it was before. I've also saved the undo,
> so your next 'make it live' won't bring the problem back."

## Notes & never

- This brings the **code** back; it does **not** undo data that was already
  saved. If the problem was a data change, say so plainly and offer to fix it
  forward instead.
- Never tell the builder to log into Netlify or open a dashboard.
- Never rewrite history or force-push to undo — republish the older deploy and add
  the undo as a new change (step 3).
