#!/bin/bash
# Fetch version data from GitLab branches and generate markdown files
set -e

REPO="/volume1/docker/hermes_read/test/xy_project_01"
OUTDIR="/volume1/docker/hermes_read/blog/src/content/versions"

# branch_name:category_folder:icon:color
BRANCHES=(
  "d65_onenet_release:z_general:📦:blue"
  "z_jili_release:z_geely:🚚:green"
  "z_xy808_release:z_xuyu808:🏭:orange"
  "gd32l235_adly_onenet:gd_general:⚡:blue"
  "jili_gd32l235:gd_geely:⚡:yellow"
  "gd32l235_adly_onenet_d92a-hat:gd_d92hat:🔧:red"
)

for entry in "${BRANCHES[@]}"; do
  IFS=: read -r branch cat icon color <<< "$entry"
  echo "=== Processing $cat ($branch) ==="
  
  OUTPATH="$OUTDIR/$cat"
  rm -rf "$OUTPATH"
  mkdir -p "$OUTPATH"
  
  cd "$REPO"
  
  # Get all commits: hash|date|message
  git log "remotes/origin/$branch" --format="%H|%aI|%s" 2>/dev/null | while IFS='|' read -r hash date msg; do
    # Try to read version from user_version.h
    version=$(git show "${hash}:user_code/universal/inc/user_version.h" 2>/dev/null \
      || git show "${hash}:user_code/inc/user_version.h" 2>/dev/null \
      || echo "")
    
    if [ -n "$version" ]; then
      ver=$(echo "$version" | grep -oP 'DEVICE_SOFTWARE_SLAVE_VERSION\s+"?\K[^"]+' | head -1)
    else
      ver="unknown"
    fi
    
    # Output: version|hash_short|date|message
    echo "${ver}|${hash:0:8}|${date}|${msg}"
  done > "/tmp/${cat}_commits.txt"
  
  # Now group by version and generate markdown
  python3 << PYEOF
import os
from collections import OrderedDict

commits_file = "/tmp/${cat}_commits.txt"
outdir = "$OUTPATH"
icon = "$icon"
color = "$color"

groups = OrderedDict()
with open(commits_file) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        parts = line.split("|", 3)
        if len(parts) < 4:
            continue
        ver, hashshort, date, msg = parts
        if ver not in groups:
            groups[ver] = []
        groups[ver].append({
            "hash": hashshort,
            "date": date[:19].replace("T", " "),
            "message": msg,
        })

for ver, commits in groups.items():
    # Sort by date ascending
    commits.sort(key=lambda x: x["date"])
    
    # Use latest commit date for filename
    latest = commits[-1]["date"]
    filename = f"cy{latest[2:4]}{latest[5:7]}{latest[8:10]}{latest[11:13]}{latest[14:16]}.md"
    
    lines = [
        "---",
        f'title: "固件 v{ver}"',
        f'icon: "{icon}"',
        f'color: "{color}"',
        "commits:",
    ]
    
    # Group by date
    date_groups = {}
    for c in commits:
        d = c["date"][:10]
        if d not in date_groups:
            date_groups[d] = []
        date_groups[d].append(c["message"])
    
    for date in sorted(date_groups.keys()):
        msgs = date_groups[date]
        lines.append(f'  - date: "{date}"')
        lines.append("    messages:")
        for msg in msgs:
            safe = msg.replace('"', '\\"')
            lines.append(f'      - "{safe}"')
    
    lines.append("---")
    lines.append("")
    
    filepath = os.path.join(outdir, filename)
    with open(filepath, "w") as f:
        f.write("\n".join(lines))

print(f"  Generated {len(groups)} files")
PYEOF

  count=$(ls "$OUTPATH"/*.md 2>/dev/null | wc -l)
  echo "  -> $count markdown files generated"
done

echo ""
echo "=== Summary ==="
for entry in "${BRANCHES[@]}"; do
  IFS=: read -r branch cat icon color <<< "$entry"
  count=$(ls "$OUTDIR/$cat"/*.md 2>/dev/null | wc -l)
  echo "  $cat: $count files"
done
