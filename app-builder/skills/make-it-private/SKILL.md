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
     password protection, Pro plan); give it to them once, plainly.
   - **Team sign-in:** turn on the matching Netlify access control (plan-dependent — see SETUP.md).
   - **Public:** remove the site password — only when they've clearly asked to open it to anyone.
3. Protection is site-level, so it covers the live site *and* its shareable previews.

## Reply

> "Done — now only people with the password can open it." (or "…only your team can
> open it," or — if they chose public — "…anyone with the link can open it now.")

## Notes & never

- This changes who can *open* the app; the link itself stays the same.
- **Making an app public is a deliberate choice** — confirm they mean it, especially if
  it holds names, client, or compliance data.
- Protection needs the site to be in the platform Netlify team + the right plan (see
  SETUP.md); if it isn't available, say so plainly.
- Never expose how it's wired, and never tell them to use the Netlify dashboard.
