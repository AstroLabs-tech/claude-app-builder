---
name: make-it-private
description: Manage who can open a published app — its password or team-sign-in protection, or make it public. Use when the builder says "make it private", "password protect it", "change the password", "only my team should see this", "make it public", "let anyone see it", or worries about who can open a live or preview link. Apps are password-protected by default; this changes that.
---

# make-it-private

Apps are **password-protected by default** (set when the app is first connected — see
new-app). This skill *changes* that: set or replace the password, switch to team
sign-in, or — only if they explicitly ask — make the app public.

## Steps

1. Ask what they want: **set/replace the password**, **team sign-in** (only people in
   the team can open it), or **public** (anyone — a deliberate opt-out).
2. Apply it on the site through the **Netlify API/CLI**, never by asking them to log in:
   - **Password:** set the site's Visitor-access password (Netlify's site-level
     password protection, Pro plan). If the builder chose a specific password, use that
     **exact** value. **Otherwise generate a strong one by default** — a Chrome-style
     15-character string (upper + lower + digits; look-alike chars `0/O`/`1/l/I` excluded
     so it survives being read aloud), hyphen-chunked into three groups of five for easy
     reading (the loop redraws until the 15 characters include at least one upper, one
     lower, and one digit):
     `while :; do p=$(LC_ALL=C tr -dc 'A-HJ-NP-Za-km-z2-9' </dev/urandom | head -c 15); [[ $p =~ [A-Z] && $p =~ [a-z] && $p =~ [2-9] ]] && break; done; echo "${p:0:5}-${p:5:5}-${p:10:5}"`
     Set that exact value on the site (hyphens included), then give the builder the
     password once, in plain words — say clearly whether you generated it — and tell them
     to save it: it's the key to their app and won't be shown again.
   - **Team sign-in:** turn on the matching Netlify access control (plan-dependent — see SETUP.md).
   - **Public:** remove the site password — only when they've clearly asked to open it to anyone.
3. **Scope protection to "All deploys," never "Non-production deploys only"** — the latter
   guards only previews/branch deploys and leaves the **live site open**. "All deploys"
   covers the live site *and* its shareable previews in one setting.

## Reply

> "Done — now only people with the password can open it." (or "…only your team can
> open it," or — if they chose public — "…anyone with the link can open it now.")

## Notes & never

- **Never let the password you set differ from the one you tell the builder.** Whether
  they chose it or you generated it, the value set on the site and the value you read back
  must be identical — otherwise they think they set one password and it's really another,
  and they lock themselves out. If you generated it, say so.
- This changes who can *open* the app; the link itself stays the same.
- **Making an app public is a deliberate choice** — confirm they mean it, especially if
  it holds names, client, or compliance data.
- Protection needs the site to be in the platform Netlify team + the right plan (see
  SETUP.md); if it isn't available, say so plainly.
- Never expose how it's wired, and never tell them to use the Netlify dashboard.
