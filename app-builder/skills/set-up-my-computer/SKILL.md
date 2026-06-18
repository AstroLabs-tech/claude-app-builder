---
name: set-up-my-computer
description: One-time setup so this computer can build and publish apps. Use when the builder says "set up my computer", "get me started", "set this up", "I'm new here", or whenever another app-builder action fails because a tool isn't installed or isn't signed in yet. Installs the needed tools and signs in using the access tokens the builder's admin gave them — never a shared password.
---

# set-up-my-computer

A one-time setup: get this computer ready to build and publish apps. Install the
needed tools, sign in with the builder's access tokens, set the organisation, and
verify it all works. Talk in plain language — don't explain or name the tooling.

## What to get from the builder
Their admin gives them **two access tokens** (one for GitHub, one for Netlify) and
the **organisation name**. Ask for these in plain words at the sign-in step —
e.g. *"Paste the GitHub access token your admin gave you."* Never ask them to log
in with a shared email or password.

## Steps

1. **Check what's already here:** `node --version`, `git --version`,
   `gh --version`, `netlify --version`. Only install what's missing.
2. **Install the missing tools** (each only if absent):
   - **Node** — via nvm (installs into the home folder, no admin password needed):
     `curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash`,
     then load nvm and run `nvm install 20`.
   - **Netlify CLI** — `npm install -g netlify-cli`.
   - **GitHub CLI** — `brew install gh` if Homebrew is present; otherwise download
     the latest release for their OS into a user folder and add it to PATH.
   - **git** — usually already present. If it's missing on a Mac, run
     `xcode-select --install`, tell them *"a system window will pop up — click
     Install,"* and wait for them to confirm. This is the one step that may need
     their click/password.
3. **Sign in with tokens** (never a shared login):
   - GitHub: ask them to paste their GitHub token, then run
     `gh auth login --with-token` fed from the pasted value.
   - Netlify: ask for their Netlify token and save it as `NETLIFY_AUTH_TOKEN` in
     their shell profile (e.g. append to `~/.zshrc`) and the current session.
4. **Set the organisation:** add `export BUILDER_GH_ORG=<org name>` to their shell
   profile and current session. The admin tells them the org — it's `AstroLabs-tech`.
5. **Verify:** confirm `gh auth status` shows them signed in and `netlify status`
   shows the team. If anything failed, explain it in one plain sentence and offer
   to retry just that piece.

## Reply when done
> "All set — your computer's ready. Want to build something? Just say:
> *start a new app called …*"

## Never
- Never ask for a shared email or password — only the tokens the admin issued.
- Never print token values back, and never save them into an app's code.
- Never show raw error logs — explain in one plain sentence and offer to fix.
