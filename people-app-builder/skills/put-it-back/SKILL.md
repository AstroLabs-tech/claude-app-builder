---
name: put-it-back
description: Roll the live app back to the previous working version. Use whenever the builder says "put it back", "undo the live version", "go back to how it was", "revert it", or otherwise wants to undo what's currently live. Instant, and it leaves the project history intact.
---

# put-it-back

Roll the live app back to the previous successful version by republishing it on
Netlify — done entirely through the tools, never a dashboard.

## Steps

1. **Find the version before the current live one.** Netlify keeps every past
   deploy. Take the newest ready **production** deploy older than the one now
   published:
   ```bash
   set -eo pipefail
   SITE_ID=$(jq -er .siteId .netlify/state.json | tr -d '\r')
   CUR=$(netlify api getSite --data "{\"site_id\":\"$SITE_ID\"}" | jq -er .published_deploy.id | tr -d '\r')
   PREV=$(netlify api listSiteDeploys --data "{\"site_id\":\"$SITE_ID\"}" \
     | jq -er --arg c "$CUR" '[.[] | select(.context == "production" and .state == "ready")] as $d
         | ($d | map(.id) | index($c)) as $i | $d[$i + 1] | .id' | tr -d '\r')
   ```
   If there's no earlier version, say there's nothing to go back to and stop.
2. **Republish it** with `netlify api restoreSiteDeploy --data '{"site_id":"…","deploy_id":"…"}'`,
   then confirm the site's `published_deploy.id` is now `$PREV`. Only then is it
   rolled back.
3. **Keep the problem from coming back.** Rolling back doesn't stop auto
   publishing, and `main` still holds the faulty version, so the next "make it live"
   would publish it again. Straight away, add the undo on top of the working line
   as one new change (never rewrite history):
   ```bash
   GOOD=<commit_ref of $PREV>
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

Only mention the saved undo if step 3 worked; otherwise say the live app is back
and the undo still needs saving before the next "make it live".

## Notes & never

- This brings the **code** back; it does **not** undo data that was already
  saved. If the problem was a data change, say so plainly and offer to fix it
  forward instead.
- Never tell the builder to log into Netlify or open a dashboard.
- Never rewrite history or force-push to undo — republish the older deploy and add
  the undo as a new change (step 3).
