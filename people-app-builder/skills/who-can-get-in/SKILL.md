---
name: who-can-get-in
description: Manage who can sign in to a People app — approve emails, remove people, or list who's approved. Use when the builder says "let Sara in", "give access to …", "add these people", "approve these emails", "remove Omar", "he left the company", "who can get in", "who has access", or pastes a list of emails to approve. Also used by new-app and make-it-live to approve the builder themselves.
---

# who-can-get-in

People apps open only for **approved emails**. Each app has two separate lists: the
**test list** (previews and "show me") and the **live list** (the real app). This
skill adds and removes people on those lists through the sign-in service's admin
API — the builder never opens a dashboard.

## Pick the list

- **Approve someone:** the **live list** if the app has gone live (it has live codes),
  otherwise the **test list**. If they say "for testing" or "for the preview", use
  the test list. Never put real staff on the test list just to be safe.
- **Remove someone:** **both lists**, always.
- **"Who can get in?":** show the list for the live app if it's live, otherwise the
  test list, and say which one it is.

## Steps

1. **Read the admin code for that list from the app's site, without printing it:**
   ```bash
   CTX=production   # live list; use CTX=dev for the test list
   SK=$(netlify env:get CLERK_SECRET_KEY --context "$CTX")
   [ -n "$SK" ] || echo "no sign-in code for $CTX"
   API=https://api.clerk.com/v1
   AUTH=(-H "Authorization: Bearer $SK" -H "Content-Type: application/json")
   ```
   No code → that list doesn't exist yet. For the live list say: *"The live sign-in
   isn't set up yet — your admin needs to finish it."* For the test list: *"Your
   admin still needs to set up sign-in for this app."*

2. **Clean the emails.** Trim, lowercase, one per line; drop duplicates and anything
   that isn't an email. If they paste a sheet, take the email column only. Read the
   count back before a bulk add of more than 10 (*"That's 112 people — add them
   all?"*).

3. **Do it:**
   - **List:**
     `curl -s "${AUTH[@]}" "$API/allowlist_identifiers?paginated=true&limit=500&offset=0" | jq -r '(.data // .)[] | .identifier'`
     If `total_count` is more than you've read, repeat with `offset=500`, `1000`, …
     until you have every entry — removal must see the whole list.
   - **Approve** (per email):
     `curl -s "${AUTH[@]}" -X POST "$API/allowlist_identifiers" -d "$(jq -n --arg e "$EMAIL" '{identifier:$e, notify:false}')"`
     If that person was removed before, also lift the block on their account:
     find them with `curl -s -G "${AUTH[@]}" "$API/users" --data-urlencode "email_address=$EMAIL" | jq -r '.[].id'`
     (always URL-encode the email — a `+` in an address otherwise turns into a space)
     and `POST $API/users/<id>/unban` for each.
   - **Remove** (per email, on both lists): find the entry id
     (`… | jq -r --arg e "$EMAIL" '(.data // .)[] | select(.identifier==$e) | .id'`),
     `DELETE $API/allowlist_identifiers/<id>`, then block any account they already
     made — find it by email as above and `POST $API/users/<id>/ban` for each.
     The list only controls who can **create** an account, so removing someone
     without blocking their account would leave them able to sign in.
     If the list approves a **whole domain** that covers this person, deleting their
     own entry isn't enough — tell the builder plainly that everyone at that domain is
     approved and offer to replace it with a list of named people first.
   An "already exists" reply on approve is fine (they're already approved).

4. **Check it worked.** Check the HTTP status of every add, delete, ban and unban
   (`curl -s -o /dev/null -w '%{http_code}'`); then list again, and for removals fetch
   each account (`GET $API/users/<id>`) and confirm `"banned": true` (for re-approvals,
   `false`). Only report success for what you verified; name anyone that didn't go
   through.

## Reply

> "Done — Sara can now sign in to the live app." / "Omar can't get in any more." /
> "112 people approved for the live app; 2 lines weren't emails, so I skipped them:
> …" / "These 14 people can sign in to the live app: …"

## Never

- Never approve a whole domain (like everyone `@astrolabs.com`) unless the builder
  explicitly asks for everyone at the company, and confirm it first.
- Never remove someone from one list only — removal is always both lists, plus
  blocking their account.
- Never print the admin code, and never save it to a file.
- Never say "allowlist", "Clerk", "API", "ban" or "instance" to the builder.
- If people who aren't on the list can still get in, the list isn't switched on for
  this app — say *"Your admin needs to switch on the approved-list setting for this
  app"* rather than guessing.
