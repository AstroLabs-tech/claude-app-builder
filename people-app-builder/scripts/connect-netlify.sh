#!/usr/bin/env bash
# new-app step 4: connect this folder's GitHub repo to a Netlify site in the AstroLabs
# People team (read-only deploy key, Next.js runtime, GitHub webhook, build-status hooks).
# Safe to re-run: it reuses the site this folder is linked to and skips finished steps.
# Usage: connect-netlify.sh <repo-slug> <site-name>   (run inside the app's folder)
# Prints key=value lines. Exit: 0 ok, 5 site name taken, 1 failure (message on stderr).

# This script's folder; on Windows the path may use backslashes, which dirname ignores.
HERE=${0%[/\\]*}
[ "$HERE" != "$0" ] || HERE=.
# shellcheck source=lib.sh
. "$HERE/lib.sh"

ORG=AstroLabs-people
TEAM="AstroLabs People"
NEXT_RUNTIME=@netlify/plugin-nextjs

[ $# -eq 2 ] || die "$E_USAGE" "usage: connect-netlify.sh <repo-slug> <site-name>"
REPO="$ORG/$1"
NAME=$2
need netlify gh jq

ERRS=$(mktemp)
trap 'rm -f "$ERRS"' EXIT

acct=$(netlify api listAccountsForUser | jqr -er --arg t "$TEAM" 'first(.[] | select(.name == $t)) | .slug') \
  || die "$E_FAIL" "this computer's Netlify sign-in isn't on the $TEAM team"

get_site() {
  netlify api getSite --data "$(jq -n --arg s "$1" '{site_id:$s}')"
}

# 1. The site: reuse the one this folder is linked to, or create it and link at once,
#    so a re-run after a later failure never makes a second site.
site=""
if [ -f .netlify/state.json ]; then
  sid=$(site_id)
  site=$(get_site "$sid") || die "$E_FAIL" "this folder is linked to a Netlify site that can't be read"
  [ "$(printf '%s' "$site" | jqr -r .account_slug)" = "$acct" ] \
    || die "$E_FAIL" "this folder is linked to a Netlify site outside the $TEAM team"
else
  if ! site=$(netlify api createSiteInTeam \
      --data "$(jq -n --arg a "$acct" --arg n "$NAME" '{account_slug:$a, body:{name:$n}}')" 2>"$ERRS"); then
    grep -qiE 'taken|unique|already|unprocessable' "$ERRS" && die "$E_TAKEN" "the site name '$NAME' is taken"
    die "$E_FAIL" "couldn't create the Netlify site: $(head -1 "$ERRS")"
  fi
  sid=$(printf '%s' "$site" | jqr -er .id) || die "$E_FAIL" "Netlify didn't return the new site's id"
  netlify link --id "$sid" >/dev/null || die "$E_FAIL" "couldn't link this folder to the new site"
fi

# 2 + 3. Deploy key and repo, unless already attached; the Next.js runtime either way
#        (without it Netlify deploys no server and every page is a 404).
attached=$(printf '%s' "$site" | jqr -r --arg r "$REPO" \
  'if (.build_settings.repo_path == $r and (.build_settings.deploy_key_id // "") != "") then "yes" else "no" end')
if [ "$attached" = no ]; then
  key=$(netlify api createDeployKey) || die "$E_FAIL" "couldn't make a deploy key"
  key_id=$(printf '%s' "$key" | jqr -er .id) || die "$E_FAIL" "unexpected deploy key reply"
  pub=$(printf '%s' "$key" | jqr -er .public_key) || die "$E_FAIL" "unexpected deploy key reply"
  gh api -X POST "repos/$REPO/keys" -f title="Netlify Deploy Key" -f key="$pub" -F read_only=true >/dev/null \
    || die "$E_FAIL" "couldn't add the deploy key to $REPO (does this sign-in have admin on it?)"
  repo_id=$(gh api "repos/$REPO" --jq .id) || die "$E_FAIL" "couldn't read $REPO"
  site=$(netlify api updateSite --data "$(jq -n --arg s "$sid" --argjson rid "$repo_id" --arg k "$key_id" \
      --arg p "$REPO" --arg plug "$NEXT_RUNTIME" \
      '{site_id:$s, body:{repo:{id:$rid, provider:"github", repo_path:$p, repo_branch:"main",
        allowed_branches:["main"], deploy_key_id:$k, cmd:"npm run build", dir:".next"},
        plugins:[{package:$plug}]}}')") \
    || die "$E_FAIL" "couldn't attach $REPO to the site"
  echo "first_build=started"
else
  has_runtime=$(printf '%s' "$site" | jqr -r --arg plug "$NEXT_RUNTIME" \
    'if any(.plugins[]?; .package == $plug) then "yes" else "no" end')
  if [ "$has_runtime" = no ]; then
    site=$(netlify api updateSite --data "$(jq -n --arg s "$sid" --arg plug "$NEXT_RUNTIME" \
        '{site_id:$s, body:{plugins:[{package:$plug}]}}')") \
      || die "$E_FAIL" "couldn't add the Next.js runtime to the site"
  fi
fi
hook=$(printf '%s' "$site" | jqr -er '.deploy_hook') || die "$E_FAIL" "Netlify didn't return the site's deploy hook"

# 4. GitHub tells Netlify about pushes and pull requests (this is what makes previews fire).
hooked=$(gh api "repos/$REPO/hooks" --jq "[.[] | select(.config.url == \"$hook\")] | length") \
  || die "$E_FAIL" "couldn't read $REPO's webhooks"
if [ "$(printf '%s' "$hooked" | tr -d '\r')" = 0 ]; then
  gh api -X POST "repos/$REPO/hooks" -f name=web -f "config[url]=$hook" -f "config[content_type]=json" \
    -f "events[]=push" -f "events[]=pull_request" -f "events[]=delete" -F active=true >/dev/null \
    || die "$E_FAIL" "couldn't add the GitHub webhook to $REPO"
fi

# 5. Netlify reports build status back on GitHub, with the token netlify init would use.
#    Once the Netlify GitHub App is installed, Netlify keeps its own github_app_* hooks;
#    those count too, so a re-run doesn't add duplicates.
have=$(netlify api listHooksBySiteId --data "$(jq -n --arg s "$sid" '{site_id:$s}')" \
  | jqr -r '.[] | select(.type == "github_commit_status" or .type == "github_app_commit_status") | .event') \
  || die "$E_FAIL" "couldn't read the site's notification hooks"
tok=""
for ev in deploy_created deploy_failed deploy_building; do
  printf '%s\n' "$have" | grep -qx "$ev" && continue
  if [ -z "$tok" ]; then
    tok=$(gh auth token) && [ -n "$tok" ] || die "$E_FAIL" "no GitHub token on this computer"
  fi
  netlify api createHookBySiteId --data "$(jq -n --arg s "$sid" --arg e "$ev" --arg t "$tok" \
      '{site_id:$s, body:{type:"github_commit_status", event:$e, data:{access_token:$t}}}')" >/dev/null \
    || die "$E_FAIL" "couldn't add the $ev status hook"
done

echo "site_id=$sid"
echo "site_name=$(printf '%s' "$site" | jqr -r .name)"
echo "site_url=$(printf '%s' "$site" | jqr -r '.ssl_url // .url')"
echo "status=connected"
