---
name: put-it-back
description: Roll the live app back to the previous working version. Use whenever the builder says "put it back", "undo the live version", "go back to how it was", "revert it", or otherwise wants to undo what's currently live. Instant, and it leaves the project history intact.
---

# put-it-back

Roll the live app back to the previous successful version by republishing it on
Netlify — done entirely through the tools, never a dashboard. The plugin's scripts do
the risky parts; run them inside the app's folder:
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/<script>"`.

## Steps

1. **Roll back:** `rollback.sh`. It republishes the last version that was really
   live before the current one, confirms it is now the live one, and prints
   `restored=<id>` and `good_commit=<sha>`.
   - Exit 6: a new live version is still building, and it would replace the rollback
     the moment it finished. Wait a little and run it again.
   - Exit 1: it says why: the app's versions couldn't be read, it couldn't tell which
     version is live (it won't guess), or there's nothing earlier to go back to.
     Explain in one plain sentence and stop.
2. **Keep the problem from coming back.** Rolling back doesn't stop auto publishing,
   and `main` still holds the faulty version, so the next "make it live" would
   publish it again. Straight away:
   - Check for someone else's work in progress (**save-preview** step 1). If another
     builder has unpublished work on the preview, ask before adding the undo on top.
   - `undo.sh <good_commit> "<what went wrong, in plain words>"`. It gets onto the
     preview line, adds one new change that undoes exactly what `main` gained after
     the good version (unpublished preview work stays), and prints `undo_commit=…`.
     Exit 4: there are unsaved changes here, so ask what to do with them first. Exit 7:
     the undo clashes with unpublished preview work. Exit 1: it says why.
   - Then make sure only approved testers can open it (**save-preview** step 4), push
     the preview and open or update its pull request as **save-preview** does.

   If anything in this step stops you, the live app is still rolled back. Say so, and
   say whether the undo is saved on this computer but not shared yet, or not made yet.
   Either way it must be done before the next "make it live". To bring a feature back
   later, fix it forward on the preview.

## Reply

> "Rolled back — your live app is the way it was before. I've also saved the undo,
> so your next 'make it live' won't bring the problem back."

Only mention the saved undo if step 2 finished; otherwise say the live app is back
and the undo still needs finishing before the next "make it live".

## Notes & never

- This brings the **code** back; it does **not** undo data that was already
  saved. If the problem was a data change, say so plainly and offer to fix it
  forward instead.
- Never tell the builder to log into Netlify or open a dashboard.
- Never rewrite history or force-push to undo — republish the older version and add
  the undo as a new change (step 2).
