---
name: set-up-my-computer
description: One-time setup so this computer (Windows or Mac) can build and publish People-team apps. Use when the builder says "set up my computer", "get me started", "set this up", "I'm new here", or whenever another app-builder action fails because a tool isn't installed or isn't signed in yet. Installs the needed tools and signs in using the access tokens the builder's admin gave them — never a shared password.
---

# set-up-my-computer

A one-time setup: get this computer ready to build and publish People-team apps.
Install the needed tools, sign in with the builder's access tokens, and verify it
all works. Talk in plain language — don't explain or name the tooling.

## What to get from the builder
Their admin gives them **two access tokens** (one for GitHub, one for Netlify).
The organisation (`AstroLabs-people`) and Netlify team (`AstroLabs People`) are
fixed for People apps, so don't ask for them. Ask for the tokens in plain words at
the sign-in step — e.g. *"Paste the GitHub access token your admin gave you."*
Never ask them to log in with a shared email or password. You'll also ask for their
**own name and work email** (so their work is credited to them, not the shared login).

**Do it for them — never hand the builder a terminal.** Run every command yourself.
Their only manual moments are clicking **Yes / Install** on a system popup. Never use
`sudo`.

## Step 0 — which computer is this?

Run `uname -s`. `Darwin` → **Mac**. `MINGW…` / `MSYS…` → **Windows (Git Bash)**.
If you only have PowerShell (no Bash tool), it's **Windows without Git** — go to the
Windows path; its first step installs Git.

## Windows path

All the People skills run their commands in **Git Bash**, so Git for Windows comes
first. Install with **winget**, always with
`--accept-package-agreements --accept-source-agreements --silent`. Several installs
show a Windows permission popup: tell the builder *"a Windows popup will ask for
permission — click Yes"* before each one and wait.

1. **Git for Windows** (only if missing — it's what gives you Git Bash):
   `winget install -e --id Git.Git …`. If you were on PowerShell only, ask the builder
   to **close and reopen the Claude app**, then continue in a new session (it now has
   Git Bash). Then set `git config --global core.autocrlf false`.
2. **Check what's already here** (in Git Bash): `node --version`, `gh --version`,
   `netlify --version`, `jq --version`. Install only what's missing:
   - **Node:** `winget install -e --id OpenJS.NodeJS.LTS …`
   - **GitHub CLI:** `winget install -e --id GitHub.cli …`
   - **jq:** `winget install -e --id jqlang.jq …`
   - **Netlify CLI:** `npm install -g netlify-cli` (installs into the user's own folder;
     no popup).
3. **Make the new tools visible.** Windows only adds new tools to programs started
   *after* the install, so put them on PATH yourself — run this in the current shell
   **and** append it to `~/.bashrc`:
   ```bash
   export PATH="/c/Program Files/nodejs:/c/Program Files/GitHub CLI:$(cygpath -u "$LOCALAPPDATA")/Microsoft/WinGet/Links:$(cygpath -u "$APPDATA")/npm:$PATH"
   ```
   Also append to `~/.bashrc` a jq wrapper, because jq on Windows ends every line with
   an invisible `\r` that breaks the next command:
   `jq() { command jq "$@" | tr -d '\r'; }`
   A "command not found" right after an install almost always means PATH, not a failed
   install — re-run the export line, don't reinstall.
4. Continue with **Sign in** below. Where it says "save to the shell profile", on
   Windows do **both**: append to `~/.bashrc` **and** `setx NAME "value"` (so the value
   survives a restart of the Claude app).
5. At the very end, ask the builder to **close and reopen the Claude app once** so
   everything is picked up cleanly.

## Mac path

1. **Check what's already here:** `node --version`, `git --version`,
   `gh --version`, `netlify --version`, `jq --version`. Only install what's missing.
2. **Install the missing tools** (each only if absent):
   - **Node (via nvm) — always activate nvm's Node, even if a `node` already exists.**
     A pre-installed *system* Node makes global installs demand a password; nvm's Node
     lives in the home folder and never does:
     ```bash
     curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
     export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh"
     nvm install 20 && nvm alias default 20
     ```
     Make sure the `NVM_DIR` / `nvm.sh` lines are in `~/.zshrc`, and **re-source them at
     the top of every later or background command** — non-login shells don't auto-load
     nvm, which is what makes `node`/`npm`/`netlify` come back "command not found".
   - **Netlify CLI** — `npm install -g netlify-cli` **using nvm's Node**. If it ever
     prompts for a password, you're on the system Node — run `nvm use 20` first.
   - **GitHub CLI** — `brew install gh` if Homebrew is present; otherwise download the
     latest release into a user folder and add it to PATH.
   - **jq** — preinstalled on recent macOS; if missing, `brew install jq` or the release
     binary in a user folder on PATH.
   - **git** — usually present. If missing, run `xcode-select --install`, tell them
     *"a system window will pop up — click Install,"* and wait for them to confirm.
3. "Save to the shell profile" below means append to `~/.zshrc` and export it in the
   current session.

## Sign in (both)

**Clean every pasted token first:** strip spaces, tabs and line breaks
(`TOKEN=$(printf '%s' "$PASTED" | tr -d '[:space:]')`). Copying from an email or chat
— especially on Windows — adds invisible characters that make a valid token look
rejected.

- **GitHub:** in order:
  - `printf '%s' "$TOKEN" | gh auth login --with-token`
  - **`gh auth setup-git`** — wires git's credential helper to the token; without it
    the first clone dies with *"could not read Username for https://github.com"*.
  - `gh config set git_protocol https` so clones use the token over HTTPS.
  - **Pre-flight the token's permissions:** it must carry **`repo`, `read:org`, and
    `workflow`** (read the scopes line from `gh auth status`). If one is missing, say
    plainly: *"The access token your admin gave you is missing a permission (name it,
    e.g. `read:org`). Ask them to reissue it with repo, read:org, and workflow."* and
    stop here.
- **Netlify:** save the cleaned token as `NETLIFY_AUTH_TOKEN` to the shell profile (see
  your path above) and the current session. Then **check `netlify status` shows the
  People team** (`AstroLabs People`) — if it doesn't, the token belongs to an account
  that isn't on the People team; say so plainly and ask the admin to add them to the
  People team and issue a new token.

## Stamp their work as theirs (both)

Everyone on the team shares one GitHub login, so the *only* record of who built what
is the name on each change. Ask for their **own name and work email** — explicitly
NOT the shared team login — e.g. *"What's your name and work email? I'll put it on
everything you make so it's credited to you."* Set it once:
`git config --global user.name "<their name>"` and
`git config --global user.email "<their own work email>"`.

## Verify (both)

`node -v`, `gh --version`, `netlify --version` and `jq --version` all respond (on a
Mac, re-source nvm first; on Windows, re-run the PATH export first); `gh auth status`
shows them signed in; `netlify status` shows the People team; and
`git config --global user.email` is their own address. If something genuinely failed,
explain it in one plain sentence and offer to retry just that piece.

## Reply when done
> "All set — your computer's ready. Want to build something? Just say:
> *start a new app called …* — or *I have a prototype* if you've already made one."

## Never
- Never tell the builder to open a terminal or paste/run commands — run everything
  yourself; their only manual moments are system popups (a click).
- Never use `sudo`, and on a Mac never lean on a system Node.
- Never ask for a shared email or password — only the tokens the admin issued.
- Never set their git identity to the shared team login.
- Never print token values back, and never save them into an app's code.
- Never push past sign-in with a token missing a scope — name the missing permission
  and ask the admin to reissue it.
- Never show raw error logs — explain in one plain sentence and offer to fix.
