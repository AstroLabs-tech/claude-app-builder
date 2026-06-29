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
in with a shared email or password. You'll also ask for their **own name and work
email** (so their work is credited to them, not the shared login).

## Steps

**Do it for them — never hand the builder a terminal.** Run every command yourself.
The builder's only manual moments are clicking **Install** on the macOS command-line-
tools popup (if git is missing) or typing their Mac password into that one system
popup — nothing else should go to a terminal. **Never use `sudo`:** keep everything in
the home folder (that's what nvm is for); if an install asks for a password, you're on
a system-installed Node — switch to nvm's Node instead of escalating.

1. **Check what's already here:** `node --version`, `git --version`,
   `gh --version`, `netlify --version`. Only install what's missing.
2. **Install the missing tools** (each only if absent):
   - **Node (via nvm) — always activate nvm's Node, even if a `node` already exists.**
     A pre-installed *system* Node makes global installs demand a password; nvm's Node
     lives in the home folder and never does. Install it, then load nvm **in the same
     shell** before using node/npm:
     ```bash
     curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
     export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh"
     nvm install 20 && nvm alias default 20
     ```
     Make sure those `NVM_DIR` / `nvm.sh` lines (and `~/.local/bin` on PATH, if you put
     the gh CLI there) are in `~/.zshrc`, and **re-source them at the top of every later
     or background command** — non-login shells don't auto-load nvm, which is what makes
     `node`/`npm`/`netlify` come back "command not found".
   - **Netlify CLI** — `npm install -g netlify-cli` **using nvm's Node** (so it needs no
     password). If it ever prompts for one, you're on the system Node — run `nvm use 20`
     first; never `sudo`.
   - **GitHub CLI** — `brew install gh` if Homebrew is present; otherwise download
     the latest release for their OS into a user folder and add it to PATH.
   - **git** — usually already present. If it's missing on a Mac, run
     `xcode-select --install`, tell them *"a system window will pop up — click
     Install,"* and wait for them to confirm. This is the one step that may need
     their click/password.
3. **Sign in with tokens** (never a shared login):
   - **GitHub:** ask them to paste their GitHub token, then, in order:
     - `gh auth login --with-token` (fed from the pasted value)
     - **`gh auth setup-git`** — wires git's credential helper to the token;
       without it the first clone dies with *"could not read Username for
       https://github.com"*.
     - `gh config set git_protocol https` so clones use the token over HTTPS
       (avoids a stray SSH key resolving to the wrong account).
     - **Pre-flight the token's permissions:** it must carry **`repo`, `read:org`,
       and `workflow`** (read the scopes line from `gh auth status`). If one is
       missing, don't surface the raw error — say plainly: *"The access token your
       admin gave you is missing a permission (name it, e.g. `read:org`). Ask them
       to reissue it with repo, read:org, and workflow."* and stop here.
   - **Netlify:** ask for their Netlify token and save it as `NETLIFY_AUTH_TOKEN` in
     their shell profile (e.g. append to `~/.zshrc`) and the current session.
4. **Stamp their work as theirs.** Everyone on the team shares one GitHub login,
   so the *only* record of who built what is the name on each change. Ask for
   their **own name and work email** — explicitly NOT the shared team login —
   e.g. *"What's your name and work email? I'll put it on everything you make so
   it's credited to you."* Set it once for this machine:
   `git config --global user.name "<their name>"` and
   `git config --global user.email "<their own work email>"`. It flows into every
   app they create, so they're never asked again.
5. **Set the organisation:** add `export BUILDER_GH_ORG=<org name>` to their shell
   profile and current session. The admin gives them the org name with the tokens
   (the ops team — the first team on the platform — uses `AstroLabs-ops`).
6. **Verify** (re-source nvm first so this shell sees the tools): `node -v`,
   `gh --version` and `netlify --version` all respond; `gh auth status` shows them
   signed in; `netlify status` shows the team; and `git config --global user.email`
   is their own address (not the shared login). A "command not found" here almost
   always means nvm isn't loaded in *this* shell — re-source it and re-check, don't
   reinstall. If something genuinely failed, explain it in one plain sentence and
   offer to retry just that piece.

## Reply when done
> "All set — your computer's ready. Want to build something? Just say:
> *start a new app called …*"

## Never
- Never tell the builder to open a terminal or paste/run commands — run everything
  yourself; the only manual moments are the macOS install popup (a click) or one
  system password prompt.
- Never use `sudo` or lean on a system Node — keep installs in nvm/home so they need
  no password.
- Never ask for a shared email or password — only the tokens the admin issued.
- Never set their git identity to the shared team login — always their own name
  and work email, so each person's work is credited to them.
- Never print token values back, and never save them into an app's code.
- Never push past sign-in with a token missing a scope — name the missing
  permission (e.g. `read:org`) and ask the admin to reissue it.
- Never show raw error logs — explain in one plain sentence and offer to fix.
