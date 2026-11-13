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
   set -o pipefail   # `set -e` does nothing in Claude Code's shell: each call has its own stop
   SITE_ID=$(jq -er .siteId .netlify/state.json | tr -d '\r') || exit 1
   CUR=$(netlify api getSite --data "{\"site_id\":\"$SITE_ID\"}" | jq -er .published_deploy.id | tr -d '\r') || exit 1
   P=1; FOUND=""; PREV=""
   while [ -z "$PREV" ]; do   # newest first, page by page: the next ready production deploy after CUR
     PAGE=$(netlify api listSiteDeploys --data "{\"site_id\":\"$SITE_ID\",\"page\":$P,\"per_page\":100}") || exit 1
     N=$(jq -er 'if type == "array" then length else error("unexpected reply") end' <<<"$PAGE") || exit 1
     # only versions that were actually live: production, ready, and published at some point
     IDS=$(jq -r '.[] | select(.context == "production" and .state == "ready" and .published_at != null) | .id' <<<"$PAGE" | tr -d '\r') || exit 1
     for ID in $IDS; do
       if [ -n "$FOUND" ]; then PREV=$ID; break; fi
       [ "$ID" = "$CUR" ] && FOUND=1
     done
     [ "$N" -eq 100 ] || break; P=$((P+1))
   done
   echo "found_current=${FOUND:-no} previous=${PREV:-none}"
   ```
   A failed read stops the block with an error: say you couldn't read the app's
   versions. `found_current=no` means the live version isn't in Netlify's list, so
   don't guess; say you couldn't tell which version to go back to. `previous=none`
   means there's nothing earlier to go back to. In all three cases, stop.
2. **Republish it** with `netlify api restoreSiteDeploy --data '{"site_id":"…","deploy_id":"…"}'`,
   then confirm the site's `published_deploy.id` is now `$PREV`. Only then is it
   rolled back.
3. **Keep the problem from coming back.** Rolling back doesn't stop auto
   publishing, and `main` still holds the faulty version, so the next "make it live"
   would publish it again. Straight away, add the undo on top of the working line
   as one new change (never rewrite history). First do **save-preview** step 1
   (someone else's work in progress); if another builder has unpublished work on
   `preview`, ask before adding the undo on top of it. If you stop here, the undo
   **hasn't been made yet**: say the live app is back, and that the undo still needs
   making before the next "make it live".
   ```bash
   set -o pipefail
   GOOD=<commit_ref of $PREV>
   git fetch origin || exit 1
   git cat-file -e "$GOOD^{commit}" || { echo "good version not found here" >&2; exit 1; }
   # get onto `preview` exactly as save-preview step 2 does (GitHub's copy if it has one)
   git diff --binary origin/main "$GOOD" | git apply --index --3way || { echo "undo didn't apply cleanly" >&2; exit 1; }
   git diff --cached --quiet && { echo "nothing to undo on the working line" >&2; exit 1; }
   git commit -q -m "Put back the version from before <the problem, in plain words>" || exit 1
   ```
   Before pushing, run **save-preview** step 4 (the test-list check). Then push
   `preview` and open or update the preview pull request as **save-preview** does.
   If that check, the push or the pull request fails, the live app is still rolled
   back: say so, and that the undo is saved on this computer but not shared yet. The diff
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
