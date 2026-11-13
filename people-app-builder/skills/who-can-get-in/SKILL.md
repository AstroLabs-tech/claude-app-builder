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

- **Approve someone:** if the app has **no live codes** yet, there's only the
  **test list**, so use it. If it has live codes, use what the builder said ("for
  testing" / "for the preview" → test list; "on the live app" → live list), and if
  they didn't say, ask once in plain words: *"Should Sara get into the live app, the
  preview you're testing, or both?"* Never guess, and never put real staff on the
  test list just to be safe. When **new-app** or **make-it-live** calls this with a
  list (`CTX`), use that list and don't ask.
- **Remove someone:** **both lists**, always.
- **"Who can get in?":** if the app has live codes, show both lists, each
  labelled (live app / testing); otherwise show the test list and say so. If one
  list can't be read, say that one couldn't be read; never show it as empty.

## Steps

On Windows, end every `jq -r` whose output you store or loop over with
`| tr -d '\r'` — jq there adds an invisible `\r` to each line.

**Each command runs in a fresh shell**, so variables and `set -o pipefail` don't
carry over from one call to the next. Put step 1 and everything that uses its
`AUTH` / `API` / `LIST` in **one** call.

1. **Read the admin code for that list from the app's site, without printing it:**
   ```bash
   set -o pipefail
   CTX=production   # live list; use CTX=dev for the test list
   SK=$(netlify env:get CLERK_SECRET_KEY --context "$CTX" --json | jq -er '.CLERK_SECRET_KEY // ""' | tr -d '\r') \
     || { echo "couldn't read this app's settings — stop" >&2; exit 1; }
   [ -n "$SK" ] || { echo "no sign-in code for $CTX" >&2; exit 3; }
   API=https://api.clerk.com/v1
   AUTH=(-H "Authorization: Bearer $SK" -H "Content-Type: application/json")
   ```
   Always use `--json`: without it a missing value prints a "No value set…"
   sentence that looks like a code. If the read itself fails, stop; never treat a
   failed read as "no list" (a removal would then skip a list that exists).
   No code (an empty answer from a successful read, exit 3) → that list doesn't
   exist yet. For the live list say: *"The live sign-in isn't set up yet — your
   admin needs to finish it."* For the test list: *"Your admin still needs to set up
   sign-in for this app."* A removal still goes ahead on the list that does exist.

2. **Clean the emails.** Trim, lowercase, one per line; drop duplicates and anything
   that isn't an email. If they paste a sheet, take the email column only. Read the
   count back before a bulk add of more than 10 (*"That's 112 people — add them
   all?"*).

3. **Do it:**
   - **List** — page until you have every entry; removal must see the whole list:
     ```bash
     OFF=0; LIST=""
     while :; do
       R=$(curl -sf "${AUTH[@]}" "$API/allowlist_identifiers?paginated=true&limit=500&offset=$OFF") \
         || { echo "couldn't read the list — stop" >&2; exit 1; }
       jq -e '(.data | type == "array") and (.total_count | type == "number")' <<<"$R" >/dev/null \
         || { echo "unexpected reply — stop" >&2; exit 1; }
       LIST+=$(jq -r '.data[] | "\(.id) \(.identifier)"' <<<"$R" | tr -d '\r')$'\n'
       TOTAL=$(jq -r .total_count <<<"$R" | tr -d '\r'); OFF=$((OFF+500))
       [ "$OFF" -lt "$TOTAL" ] || break
     done
     ```
     Each line of `$LIST` is an entry id, then its email. Keep it in memory only;
     never write it to a file.
   - **Approve** (per email), keeping the answer and its status:
     ```bash
     OUT=$(curl -s -w '\n%{http_code}' "${AUTH[@]}" -X POST "$API/allowlist_identifiers" \
       -d "$(jq -n --arg e "$EMAIL" '{identifier:$e, notify:false}')")
     CODE=${OUT##*$'\n'}   # 200 = added; a 4xx saying it already exists = already approved
     ```
     If that person was removed before, also lift the block on their account, but
     **only after the add answered 200 or "already exists"** (never unban someone
     whose approval failed: a blocked account that isn't on the list could then sign
     in). Look them up in two checked steps (always URL-encode the email, since a
     `+` in an address otherwise turns into a space):
     ```bash
     U=$(curl -sf -G "${AUTH[@]}" "$API/users" --data-urlencode "email_address=$EMAIL") || exit 1
     jq -e 'type == "array"' <<<"$U" >/dev/null || exit 1
     ```
     Then `POST $API/users/<id>/unban` only for accounts where **this address is
     verified**:
     `jq -r --arg e "$EMAIL" '.[] | select(any(.email_addresses[]; (.email_address | ascii_downcase) == $e and .verification.status == "verified")) | .id' <<<"$U"`.
     An empty array just means no account yet. If that lookup fails (curl or jq errors), say the approval went through
     but the old block couldn't be checked.
   - **Remove** (per email, on both lists), in this order: first look up any
     account they made, with the two checked steps above. That lookup must succeed;
     if either step fails, stop, because the removal is **not done**. Block
     **every** account the lookup returns, verified or not: removal fails closed. An
     account that only held this address **unverified** may be someone else's: tell
     the builder (by its verified address, if it has one). To unblock it, approve
     that person's own email; **Approve** lifts the block, with its checks. Then find the entry id
     in the full list above (compare emails lowercased), `DELETE $API/allowlist_identifiers/<id>`, and
     `POST $API/users/<id>/ban` for each account found. Never report someone as
     removed without having checked for their account.
     The list only controls who can **create** an account, so removing someone
     without blocking their account would leave them able to sign in.
     If the list approves a **whole domain** that covers this person, deleting their
     own entry isn't enough — tell the builder plainly that everyone at that domain is
     approved and offer to replace it with a list of named people first.
   An "already exists" reply on approve is fine (they're already approved).

4. **Check it worked.** Check the HTTP status of every add, delete, ban and unban
   (`curl -s -o /dev/null -w '%{http_code}'`); then list again, and for removals fetch
   each account (`GET $API/users/<id>`) and confirm `"banned": true` (for re-approvals,
   `false` on each account you unbanned). Only report success for what you verified; name anyone that didn't go
   through.

## Switch the list on

Run this in the **same call** as step 1 (for this list's `CTX`) and the **List**
loop from step 3: it needs their `AUTH`, `API` and `LIST`.
Adding emails doesn't switch the list on. It only works once the app's approved-list
setting is on. Switch it on and check the answer; it's safe to repeat:
```bash
R=$(curl -sf "${AUTH[@]}" -X PATCH "$API/instance/restrictions" -d '{"allowlist":true}') \
  || { echo "couldn't change the list setting (check the sign-in code) — stop" >&2; exit 1; }
ON=$(jq -r .allowlist <<<"$R" | tr -d '\r')
[ "$ON" = true ] || { echo "list not on — stop" >&2; exit 1; }
```
- Do it **after** at least the builder's own email is approved; otherwise nobody can
  create an account.
- If it doesn't come back `true`, stop and say *"Your admin needs to switch on the
  approved-list setting for this app."*
- **new-app**, **save-preview** and **make-it-live** run this whole step too,
  including the account check below.

**Then check the accounts that already exist** — the list only stops new accounts,
so one made before the list was on can still sign in. List every account that isn't
blocked and compare its **verified** addresses, lowercased, with `$LIST` (an
unverified address proves nothing: anyone can add one):
```bash
OFF=0
while :; do
  P=$(curl -sf "${AUTH[@]}" "$API/users?limit=500&offset=$OFF") || { echo "couldn't read accounts — stop" >&2; exit 1; }
  N=$(jq -er 'if type == "array" then length else error("unexpected reply") end' <<<"$P") || exit 1
  jq -r '.[] | select(.banned | not) | "\(.id) \([.email_addresses[] | select(.verification.status == "verified") | .email_address] | join(","))"' <<<"$P" | tr -d '\r'
  [ "$N" -eq 500 ] || break; OFF=$((OFF+500))   # page on the raw page size, not the filtered lines
done
```
If that read fails, treat it as not checked. An address is approved when the list
holds it (lowercased) or holds a whole-domain entry that covers it. Any account with
no verified approved address is **unapproved access**: name those people to the builder and ask whether to
approve or block each one, then do it. The list only counts as on when the switch
came back `true` **and** no unapproved account is left. Until then, never say only
approved people can get in.

## Reply

> "Done — Sara can now sign in to the live app." / "Omar can't get in any more." /
> "112 people approved for the live app; 2 lines weren't emails, so I skipped them:
> …" / "These 14 people are approved for the live app: …" (and, if any, "2 older
> accounts aren't on the list and can still sign in — approve or block them?")

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
