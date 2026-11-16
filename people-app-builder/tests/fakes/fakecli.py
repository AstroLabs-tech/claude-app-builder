#!/usr/bin/env python3
"""Fake netlify, gh and curl (Clerk Backend API) for the people-app-builder script tests.

tests/run.sh puts a wrapper for each tool first on PATH. State lives in the
JSON file named by $FAKE_STATE; every call is appended to $FAKE_LOG. A test makes any call
fail by putting its key in a "fail" map (netlify: API method; gh/clerk: see below).
"""

import json
import os
import subprocess
import sys
import urllib.parse

STATE_PATH = os.environ["FAKE_STATE"]
LOG_PATH = os.environ.get("FAKE_LOG", "/dev/null")


def load():
    with open(STATE_PATH) as f:
        return json.load(f)


def save(state):
    with open(STATE_PATH, "w") as f:
        json.dump(state, f, indent=1)


def log(line):
    with open(LOG_PATH, "a") as f:
        f.write(line + "\n")


def out(obj):
    sys.stdout.write(json.dumps(obj) + "\n")


def fail(msg, code=1):
    sys.stderr.write(msg + "\n")
    sys.exit(code)


def jq_filter(data, expr):
    res = subprocess.run(["jq", "-r", expr], input=json.dumps(data), capture_output=True, text=True)
    if res.returncode:
        fail(res.stderr.strip(), res.returncode)
    sys.stdout.write(res.stdout)


# ---------------------------------------------------------------- netlify
def netlify(args):
    st = load()
    n = st.setdefault("netlify", {})
    log("netlify " + " ".join(args))
    if args[0] == "api":
        method = args[1]
        data = json.loads(args[args.index("--data") + 1]) if "--data" in args else {}
        if method in n.get("fail", {}):
            fail("Error: " + n["fail"][method])
        sites = n.setdefault("sites", {})
        if method == "listAccountsForUser":
            return out(n.get("accounts", []))
        if method == "createSiteInTeam":
            name = data["body"]["name"]
            if name in n.get("taken_names", []) or any(s["name"] == name for s in sites.values()):
                fail("Error: Unprocessable Entity: name already taken")
            sid = "site-%d" % (len(sites) + 1)
            sites[sid] = {"id": sid, "name": name, "account_slug": data["account_slug"],
                          "url": "https://%s.netlify.app" % name, "build_settings": {}, "plugins": []}
            save(st)
            return out(sites[sid])
        if method == "getSite":
            sid = data["site_id"]
            if sid.endswith(".netlify.app"):
                name = sid[: -len(".netlify.app")]
                sid = next((k for k, v in sites.items() if v["name"] == name), sid)
            if sid not in sites:
                fail("Error: Not Found")
            return out(sites[sid])
        if method == "createDeployKey":
            keys = n.setdefault("deploy_keys", [])
            key = {"id": "key-%d" % (len(keys) + 1), "public_key": "ssh-rsa AAAA%d" % (len(keys) + 1)}
            keys.append(key)
            save(st)
            return out(key)
        if method == "updateSite":
            site = sites[data["site_id"]]
            body = data["body"]
            if "repo" in body:
                site["build_settings"] = dict(body["repo"])
                site["deploy_hook"] = "https://api.netlify.com/hooks/github"
            if "plugins" in body:
                site["plugins"] = body["plugins"]
            save(st)
            return out(site)
        if method == "listHooksBySiteId":
            return out(n.setdefault("hooks", {}).get(data["site_id"], []))
        if method == "createHookBySiteId":
            hooks = n.setdefault("hooks", {}).setdefault(data["site_id"], [])
            hooks.append({"type": data["body"]["type"], "event": data["body"]["event"]})
            save(st)
            return out(hooks[-1])
        if method == "listSiteDeploys":
            deploys = n.setdefault("deploys", {}).get(data["site_id"], [])
            page, per = int(data.get("page", 1)), int(data.get("per_page", 100))
            return out(deploys[(page - 1) * per: page * per])
        if method == "listSiteBuilds":
            return out(n.setdefault("builds", {}).get(data["site_id"], []))
        if method == "restoreSiteDeploy":
            site = sites[data["site_id"]]
            if not n.get("restore_noop"):
                site["published_deploy"] = {"id": data["deploy_id"]}
            if n.get("restore_adds_build"):
                n.setdefault("deploys", {}).setdefault(data["site_id"], []).insert(
                    0, {"id": "dnew", "context": "production", "state": "building", "published_at": None, "commit_ref": "cn"})
            save(st)
            return out({"id": data["deploy_id"]})
        fail("fake netlify: unknown api method " + method)
    if args[0] == "env:get":
        name = args[1]
        ctx = args[args.index("--context") + 1]
        sid = linked_site()
        if not sid:
            return sys.stdout.write("No project id found, please run inside a project folder or `netlify link`\n")
        value = n.setdefault("env", {}).get(sid, {}).get(name, {}).get(ctx)
        if "--json" in args:
            return out({name: value} if value else {})
        return sys.stdout.write((value or "No value set in the %s context for environment variable %s" % (ctx, name)) + "\n")
    if args[0] == "env:set":
        if "env:set" in n.get("fail", {}):
            fail("Error: " + n["fail"]["env:set"])
        name, value = args[1], args[2]
        ctxs = args[args.index("--context") + 1:] if "--context" in args else ["all"]
        sid = linked_site()
        env = n.setdefault("env", {}).setdefault(sid, {}).setdefault(name, {})
        for c in ctxs:
            env[c] = value
        save(st)
        return sys.stdout.write("Set environment variable %s=%s\n" % (name, value))
    if args[0] == "link":
        if n.pop("link_fail_once", None):
            save(st)
            fail("Error: link failed")
        sid = args[args.index("--id") + 1]
        os.makedirs(".netlify", exist_ok=True)
        with open(".netlify/state.json", "w") as f:
            json.dump({"siteId": sid}, f)
        return sys.stdout.write("Linked to %s\n" % sites_name(st, sid))
    fail("fake netlify: unknown command " + args[0])


def linked_site():
    """Like the real CLI: the site this folder is linked to, from .netlify/state.json."""
    try:
        with open(".netlify/state.json") as f:
            return json.load(f).get("siteId")
    except (OSError, ValueError):
        return None


def sites_name(st, sid):
    return st["netlify"]["sites"].get(sid, {}).get("name", sid)


# ---------------------------------------------------------------- gh
def gh(args):
    st = load()
    g = st.setdefault("github", {})
    log("gh " + " ".join(args))
    jq_expr = args[args.index("--jq") + 1] if "--jq" in args else None
    if args[:2] == ["auth", "token"]:
        return sys.stdout.write(g.get("token", "") + "\n")
    if args[0] == "api":
        method = args[args.index("-X") + 1] if "-X" in args else "GET"
        path = next(a for a in args[1:] if a.startswith("repos/"))
        parts = path.split("/")
        if parts[1:3] == ["{owner}", "{repo}"] and parts[3] == "pulls" and parts[5] == "commits":
            pr = g.get("prs", {}).get(parts[4])
            if pr is None:
                fail("gh: Not Found (HTTP 404)")
            # REST lists each commit's author only (co-authors live in the message)
            data = [{"commit": {"author": {"email": (c.get("authors") or [{}])[0].get("email")}}}
                    for c in pr.get("commits", [])]
            if any(c.get("authors") is None for c in pr.get("commits", [])):
                fail("gh: unexpected reply")
            return jq_filter(data, jq_expr) if jq_expr else out(data)
        repo = g.setdefault("repos", {}).get("/".join(parts[1:3]))
        if repo is None:
            fail("gh: Not Found (HTTP 404)")
        sub = parts[3] if len(parts) > 3 else ""
        if sub in g.get("fail", {}):
            fail("gh: " + g["fail"][sub])
        fields = {}
        for i, a in enumerate(args):
            if a in ("-f", "-F"):
                k, _, v = args[i + 1].partition("=")
                fields.setdefault(k, []).append(v)
        if sub == "" and method == "GET":
            data = {"id": repo["id"], "full_name": "/".join(parts[1:3])}
        elif sub == "keys" and method == "POST":
            repo.setdefault("keys", []).append({"key": fields["key"][0], "read_only": True})
            save(st)
            data = repo["keys"][-1]
        elif sub == "hooks" and method == "POST":
            repo.setdefault("hooks", []).append({"config": {"url": fields["config[url]"][0]},
                                                 "events": fields["events[]"]})
            save(st)
            data = repo["hooks"][-1]
        elif sub == "hooks" and method == "GET":
            data = repo.get("hooks", [])
        else:
            fail("fake gh: unhandled api call " + " ".join(args))
        return jq_filter(data, jq_expr) if jq_expr else out(data)
    if args[0] == "pr":
        prs = g.setdefault("prs", {})
        if args[1] == "list":
            head = args[args.index("--head") + 1]
            state = args[args.index("--state") + 1]
            data = [p for p in prs.values() if p["head"] == head and p["state"] == state.upper()]
            return jq_filter(data, jq_expr) if jq_expr else out(data)
        num = args[2]
        pr = prs.get(num)
        if pr is None:
            fail("no pull requests found")
        if args[1] == "view":
            return jq_filter(pr, jq_expr) if jq_expr else out(pr)
        if args[1] == "merge":
            want = args[args.index("--match-head-commit") + 1] if "--match-head-commit" in args else None
            if want and want != pr["headRefOid"]:
                fail("GraphQL: Head branch was modified. Review and try the merge again.")
            pr["state"] = "MERGED"
            pr["mergeCommit"] = {"oid": pr.get("merge_sha", "merge-" + pr["headRefOid"])}
            # merging starts the production deploy the test set up for it
            n = st.setdefault("netlify", {})
            for sid, deploys in pr.get("on_merge_deploys", {}).items():
                n.setdefault("deploys", {}).setdefault(sid, [])[:0] = deploys
            for sid, dep in pr.get("on_merge_publish", {}).items():
                n["sites"][sid]["published_deploy"] = {"id": dep}
            save(st)
            return sys.stdout.write("Merged\n")
    fail("fake gh: unhandled " + " ".join(args))


# ---------------------------------------------------------------- curl (Clerk)
def curl(args):
    st = load()
    clerk = st.setdefault("clerk", {})
    method, url, data, write_out, get_mode, encoded = "GET", None, None, None, False, []
    i = 0
    while i < len(args):
        a = args[i]
        if a == "-X":
            method = args[i + 1]; i += 1
        elif a in ("--data", "-d"):
            data = args[i + 1]; i += 1
        elif a == "--data-urlencode":
            encoded.append(args[i + 1]); i += 1
        elif a == "-w":
            write_out = args[i + 1]; i += 1
        elif a == "-G":
            get_mode = True
        elif a in ("-K", "--config"):
            i += 1
        elif a.startswith("http"):
            url = a
        i += 1
    config = sys.stdin.read()
    key = config.split("Bearer ", 1)[1].split('"')[0].strip() if "Bearer " in config else ""
    if "Bearer" in " ".join(args):
        fail("fake curl: the secret key was passed on the command line", 99)
    log("curl %s %s" % (method, url.split("/v1", 1)[1] if url else url))
    inst = clerk.get(key)

    def respond(code, body):
        sys.stdout.write(json.dumps(body))
        if write_out:
            sys.stdout.write(write_out.replace("\\n", "\n").replace("%{http_code}", str(code)))
        sys.exit(0)

    if inst is None:
        respond(401, {"errors": [{"code": "authentication_invalid"}]})
    parsed = urllib.parse.urlparse(url)
    path = parsed.path.split("/v1", 1)[1]
    query = dict(urllib.parse.parse_qsl(parsed.query))
    for e in encoded:
        k, _, v = e.partition("=")
        query[k] = v
    if path in inst.get("fail", {}):
        respond(inst["fail"][path], {"errors": [{"code": "internal"}]})
    once = inst.get("fail_once", {})
    if "%s %s" % (method, path) in once:
        code = once.pop("%s %s" % (method, path))
        save(st)
        respond(code, {"errors": [{"code": "internal"}]})
    if path == "/allowlist_identifiers" and method == "GET":
        off, lim = int(query.get("offset", 0)), int(query.get("limit", 10))
        items = inst.setdefault("allowlist", [])
        respond(200, {"data": items[off:off + lim], "total_count": len(items)})
    if path == "/allowlist_identifiers" and method == "POST":
        ident = json.loads(data)["identifier"]
        items = inst.setdefault("allowlist", [])
        if any(x["identifier"] == ident for x in items):
            respond(422, {"errors": [{"code": "duplicate_record", "message": "already exists"}]})
        items.append({"id": "alw_%d" % (len(items) + 100), "identifier": ident})
        save(st)
        respond(200, items[-1])
    if path.startswith("/allowlist_identifiers/") and method == "DELETE":
        aid = path.rsplit("/", 1)[1]
        inst["allowlist"] = [x for x in inst.get("allowlist", []) if x["id"] != aid]
        save(st)
        respond(200, {"id": aid, "deleted": True})
    if path == "/instance/restrictions" and method == "PATCH":
        if inst.get("allowlist_locked_off"):
            respond(200, {"allowlist": False})
        inst.setdefault("restrictions", {}).update(json.loads(data))
        save(st)
        respond(200, inst["restrictions"])
    users = inst.setdefault("users", [])
    if path == "/users" and method == "GET":
        if "email_address" in query:
            want = query["email_address"].lower()
            hits = [u for u in users if any(e["email_address"].lower() == want for e in u["email_addresses"])]
            off, lim = int(query.get("offset", 0)), int(query.get("limit", 10))
            respond(200, hits[off:off + lim])
        off, lim = int(query.get("offset", 0)), int(query.get("limit", 10))
        respond(200, users[off:off + lim])
    if path.startswith("/users/"):
        uid = path.split("/")[2]
        user = next((u for u in users if u["id"] == uid), None)
        if user is None:
            respond(404, {"errors": [{"code": "resource_not_found"}]})
        if path.endswith("/ban") and method == "POST":
            user["banned"] = True; save(st); respond(200, user)
        if path.endswith("/unban") and method == "POST":
            user["banned"] = False; save(st); respond(200, user)
        respond(200, user)
    respond(404, {"errors": [{"code": "unhandled_in_fake", "path": path}]})


# ---------------------------------------------------------------- npm
def npm(args):
    log("npm " + " ".join(args))
    if args[:1] == ["install"]:
        os.makedirs("node_modules", exist_ok=True)
        return
    if args[:2] == ["run", "dev"]:
        pk = os.environ.get("NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY", "")
        sk = os.environ.get("CLERK_SECRET_KEY", "")
        sys.stdout.write("Local: http://localhost:3000 pk=%s sk=%s\n" % (pk[:8], "set" if sk else "missing"))
        return
    fail("fake npm: unhandled " + " ".join(args))


# Called as: fakecli.py <tool> <args...>   (tests/run.sh writes a wrapper per tool)
{"netlify": netlify, "gh": gh, "curl": curl, "npm": npm}[sys.argv[1]](sys.argv[2:])
