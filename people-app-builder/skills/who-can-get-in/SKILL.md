---
name: who-can-get-in
description: Manage who can sign in to a People app — approve emails, remove people, or list who's approved. Use when the builder says "let Sara in", "give access to …", "add these people", "approve these emails", "remove Omar", "he left the company", "who can get in", "who has access", or pastes a list of emails to approve. Also used by new-app, save-preview and make-it-live to approve the builder and switch the list on.
---

# who-can-get-in

People apps open only for **approved emails**. Each app has two separate lists: the
**test list** (previews and "show me") and the **live list** (the real app). This
skill changes them with the plugin's `access.sh` script, run inside the app's folder.
The script reads the app's sign-in admin code itself; it is never printed or typed.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/access.sh" <command> …
```

## Pick the list

First see which lists exist: `access.sh lists` prints `test=yes|no` and `live=yes|no`.

- **Approve someone:** with no live list yet, use the **test list**. With a live
  list, use what the builder said ("for testing" / "for the preview" → test; "on the
  live app" → live). If they didn't say, ask once: *"Should Sara get into the live
  app, the preview you're testing, or both?"* Never guess, and never put real staff
  on the test list just to be safe. When **new-app**, **save-preview** or
  **make-it-live** names the list, use that list and don't ask.
- **Remove someone:** always both lists; `remove` does that by itself.
- **"Who can get in?":** show every list that exists, each labelled (live app /
  testing). If one can't be read, say so; never show it as empty.

## Commands

Clean what the builder pasted first: one email per line, the email column only from a
sheet. Read the count back before adding more than 10 (*"That's 112 people — add them
all?"*). The script lowercases and trims, and skips anything that isn't an email.

| Command | What it prints |
| --- | --- |
| `access.sh list <test\|live>` | `approved <email>` lines, then `count=N` |
| `access.sh approve <test\|live> <email>…` | per email: `approved`, `already`, `skipped … not-an-email`, `failed …`, `unblocked …` (an old block lifted), or `unchecked … old-block-not-checked` |
| `access.sh remove <email>…` | per list: `removed <email> <list>`, `also_blocked <list> <id> <their email>` (someone else's account that held this address unverified), `covered_by_domain <email> <list>`, `no_list <list>` |
| `access.sh lock <test\|live>` | `locked=yes`, or `unapproved <id> <emails>` lines |
| `access.sh block <account-id>…` | `blocked <id> <list>`, or `failed <id> …` |

`remove` looks every account up **before** changing anything, takes the person off
both lists, and blocks every account that holds the address, because the list only
stops *new* accounts. For `also_blocked`, tell the builder whose account it was;
approving that person's own email unblocks it. For `covered_by_domain`, say plainly
that everyone at that domain is approved, and offer to replace that with named people.

## Switch the list on (`lock`)

Adding emails doesn't switch the list on. `lock` switches it on, checks it stuck, then
checks every account that already exists: one made before the list was on can still
sign in. Only **verified** addresses count, and a whole-domain entry covers its domain.
Run it **after** at least the builder's own email is approved.

- `locked=yes` (exit 0): only approved people can get in.
- `unapproved …` lines (exit 4): name those people to the builder and ask, for each,
  whether to approve or remove them (`approve` / `remove` by email). An account shown
  as `no-verified-address` has no email to act on: if the builder doesn't recognise
  it, `block <account-id>`. Then run `lock` again. Until it passes, never say only
  approved people can get in.

## Exit codes

0 done · 1 something failed (the `STOP:` line says what; per-email failures are also
listed) · 3 that list isn't set up yet (*live*: "The live sign-in isn't set up yet —
your admin needs to finish it." *test*: "Your admin still needs to set up sign-in for
this app.") · 4 accounts need the builder's decision (`lock`).
Only report what the script printed as done; name anyone that didn't go through.

## Reply

> "Done — Sara can now sign in to the live app." / "Omar can't get in any more." /
> "112 people approved for the live app; 2 lines weren't emails, so I skipped them:
> …" / "These 14 people are approved for the live app: …" (and, if any, "2 older
> accounts aren't on the list and can still sign in — approve or remove them?")

## Never

- Never approve a whole domain (like everyone `@astrolabs.com`) unless the builder
  explicitly asks for everyone at the company, and confirm it first.
- Never remove someone from one list only — `remove` always does both lists and
  blocks their account.
- Never read, print or type the admin code yourself; the script handles it.
- Never say "allowlist", "Clerk", "API", "ban" or "instance" to the builder.
