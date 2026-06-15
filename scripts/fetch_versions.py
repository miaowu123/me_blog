#!/usr/bin/env python3
"""Fetch version data from GitLab branches (read-only) and generate markdown files."""
import os, re, subprocess
from collections import OrderedDict

REPO = "/volume1/docker/hermes_read/test/xy_project_01"
OUTDIR = "/volume1/docker/hermes_read/blog/src/content/versions"

BRANCHES = [
    ("d65_onenet_release", "z_general", "📦", "blue"),
    ("z_jili_release", "z_geely", "🚚", "green"),
    ("z_xy808_release", "z_xuyu808", "🏭", "orange"),
    ("gd32l235_adly_onenet", "gd_general", "⚡", "blue"),
    ("jili_gd32l235", "gd_geely", "⚡", "yellow"),
    ("gd32l235_adly_onenet_d92a-hat", "gd_d92hat", "🔧", "red"),
]

VER_RE = re.compile(r'DEVICE_SOFTWARE_SLAVE_VERSION\s+"([^"]+)"')

def git(*args):
    r = subprocess.run(["git", "-C", REPO] + list(args),
                        capture_output=True, text=True, timeout=30)
    return r.stdout

def get_version_at_commit(commit_hash):
    """Try multiple paths for user_version.h"""
    paths = [
        "user_code/universal/inc/user_version.h",
        "user_code/inc/user_version.h",
    ]
    for p in paths:
        try:
            content = git("show", f"{commit_hash}:{p}")
            if content and "DEVICE_SOFTWARE_SLAVE_VERSION" in content:
                m = VER_RE.search(content)
                if m:
                    return m.group(1)
        except:
            pass
    return "unknown"

for branch, cat, icon, color in BRANCHES:
    print(f"Processing {cat} ({branch})...")
    
    # Get all commits: hash, date, message
    log = git("log", f"remotes/origin/{branch}", "--format=%H|%aI|%s")
    raw_lines = [l for l in log.strip().split("\n") if l.strip()]
    
    commits = []
    for line in raw_lines:
        parts = line.split("|", 2)
        if len(parts) < 3:
            continue
        h, date_raw, msg = parts
        date = date_raw[:19].replace("T", " ")
        ver = get_version_at_commit(h)
        commits.append((ver, h[:8], date, msg))
    
    # Group by version
    groups = OrderedDict()
    for ver, h, date, msg in commits:
        groups.setdefault(ver, []).append((h, date, msg))
    
    # Generate markdown
    catdir = os.path.join(OUTDIR, cat)
    os.makedirs(catdir, exist_ok=True)
    # Clear old
    for f in os.listdir(catdir):
        os.remove(os.path.join(catdir, f))
    
    for ver, vcommits in groups.items():
        vcommits.sort(key=lambda x: x[1])  # ascending by date
        latest = vcommits[-1][1]
        fn = f"cy{latest[2:4]}{latest[5:7]}{latest[8:10]}{latest[11:13]}{latest[14:16]}.md"
        
        # Group by date
        by_date = {}
        for _, date, msg in vcommits:
            d = date[:10]
            by_date.setdefault(d, []).append(msg)
        
        lines = ["---", f'title: "固件 v{ver}"', f'icon: "{icon}"', f'color: "{color}"', "commits:"]
        for d in sorted(by_date.keys()):
            lines.append(f'  - date: "{d}"')
            lines.append("    messages:")
            for msg in by_date[d]:
                # Use single-quote YAML strings, escape single quotes inside
                safe = msg.replace("'", "''")
                lines.append(f"      - '{safe}'")
        lines.append("---")
        lines.append("")
        
        with open(os.path.join(catdir, fn), "w") as f:
            f.write("\n".join(lines))
    
    print(f"  -> {len(groups)} versions from {len(commits)} commits")

print("\nDone!")
