---
name: put-it-back
description: Roll the live site back to the previous working version. Use whenever the builder says "put it back", "undo the live version", "go back to how it was", "revert it", or otherwise wants to undo what's currently live. Instant, and it leaves the project history intact.
---

# put-it-back

Roll the live site back to the previous successful version by republishing it on
Netlify — done entirely through the tools, never a dashboard.

## Steps

1. Find the previous successful **production** deploy (Netlify keeps every past
   deploy). List them, then pick the one before the current live version —
   e.g. `netlify api listSiteDeploys` to find it, then `netlify api
   restoreSiteDeploy` (or the Netlify MCP rollback tool) to republish it.
2. Republish that deploy as the live site and wait for it to take effect.
3. The project's history on `main` is left untouched — this only changes what is
   published.

## Reply

> "Rolled back — your live site is the way it was before."

## Notes & never

- This brings the **code** back; it does **not** undo data that was already
  saved. If the problem was a data change, say so plainly and offer to fix it
  forward instead.
- Never tell the builder to log into Netlify or open a dashboard.
- Never rewrite history or force-push to undo — only republish the older deploy.
