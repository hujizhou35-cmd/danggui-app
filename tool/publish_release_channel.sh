#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <manifest.json>" >&2
  exit 64
fi

repository_root="$(git rev-parse --show-toplevel)"
manifest_path="$(realpath "$1")"
if [[ ! -f "${manifest_path}" ]]; then
  echo "Release channel manifest not found: ${manifest_path}" >&2
  exit 66
fi

worktree="$(mktemp -d)"
cleanup() {
  git -C "${repository_root}" worktree remove --force "${worktree}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

if git fetch --no-tags origin \
  '+refs/heads/release-channel:refs/remotes/origin/release-channel' \
  >/dev/null 2>&1; then
  git -C "${repository_root}" worktree add --detach \
    "${worktree}" refs/remotes/origin/release-channel
else
  git -C "${repository_root}" worktree add --detach "${worktree}" HEAD
  git -C "${worktree}" switch --orphan release-channel
  git -C "${worktree}" rm -rf . >/dev/null 2>&1 || true
fi

cp "${manifest_path}" "${worktree}/current.json"
if git -C "${worktree}" show HEAD:current.json >/dev/null 2>&1; then
  old_manifest="$(mktemp)"
  git -C "${worktree}" show HEAD:current.json > "${old_manifest}"
  if node -e '
    const fs = require("node:fs");
    const [beforePath, afterPath] = process.argv.slice(1);
    const before = JSON.parse(fs.readFileSync(beforePath, "utf8"));
    const after = JSON.parse(fs.readFileSync(afterPath, "utf8"));
    delete before.generatedAt;
    delete after.generatedAt;
    process.exit(JSON.stringify(before) === JSON.stringify(after) ? 0 : 1);
  ' "${old_manifest}" "${manifest_path}"; then
    echo "Release channel is already current."
    exit 0
  fi
fi

git -C "${worktree}" add current.json
if git -C "${worktree}" diff --cached --quiet; then
  echo "Release channel is already current."
  exit 0
fi

release_tag="$(node -e '
  const data = require(process.argv[1]);
  const selected = data.recommended ? data[data.recommended] : null;
  process.stdout.write(selected?.tag ?? "empty");
' "${manifest_path}")"
git -C "${worktree}" config user.name 'github-actions[bot]'
git -C "${worktree}" config user.email '41898282+github-actions[bot]@users.noreply.github.com'
git -C "${worktree}" commit -m "chore: publish release channel ${release_tag}"
git -C "${worktree}" push origin HEAD:refs/heads/release-channel
