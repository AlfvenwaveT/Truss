#!/usr/bin/env bash
# Run on the Mac: pull TB2.1 task images from ACR and give each the exact name its task.toml uses
# (alexgshaw/<task>:<tag>). Harbor starts prebuilt images with `docker compose up` and no --pull,
# so it uses these local copies and never goes to Docker Hub.
#
#   docker login --username=<ACR login name> <ACR_REGISTRY>    # once
#   ACR_REGISTRY=<address> ACR_NAMESPACE=<ns> [ACR_REPOSITORY=<repo>] ./pull-from-acr.sh [list] [filter]
#
#   list    image list, default images.txt next to this script (one docker.io/alexgshaw/... per line)
#   filter  pull only references containing this text, e.g. a task name
#   ACR_REPOSITORY  set it if the workflow put every image in one repository (tag <task>-<tag>)
#   REPORT  optional path to the workflow's report.tsv: each pulled image's digest must match it
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
list="${1:-$here/images.txt}"
only="${2:-}"
: "${ACR_REGISTRY:?set ACR_REGISTRY, the address in the ACR docker login command}"
: "${ACR_NAMESPACE:?set ACR_NAMESPACE}"
report="${REPORT:-}"

pulled=0; present=0
while read -r src <&3; do
  [ -z "$src" ] && continue
  case "$src" in \#*) continue ;; esac
  if [ -n "$only" ] && [[ "$src" != *"$only"* ]]; then continue; fi
  name="${src#docker.io/}"                              # alexgshaw/fix-git:20260403, as in task.toml
  name_tag="${src##*/}"                                 # fix-git:20260403
  if [ -n "${ACR_REPOSITORY:-}" ]; then
    acr="$ACR_REGISTRY/$ACR_NAMESPACE/$ACR_REPOSITORY:${name_tag/:/-}"   # <registry>/<ns>/<repo>:fix-git-20260403
  else
    acr="$ACR_REGISTRY/$ACR_NAMESPACE/$name_tag"                         # <registry>/<ns>/fix-git:20260403
  fi
  if docker image inspect "$name" >/dev/null 2>&1; then
    echo "present  $name"; present=$((present+1)); continue
  fi
  docker pull --platform linux/amd64 "$acr"
  if [ -n "$report" ]; then
    want=$(awk -F'\t' -v s="$src" '$1 == s {print $3}' "$report")
    got=$(docker image inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' "$acr" | sed -n 's/.*@//p' | head -1)
    if [ -z "$want" ] || [ "$got" != "$want" ]; then
      echo "digest check failed for $src: report '${want:-none}', pulled '${got:-none}'" >&2
      exit 1
    fi
  fi
  docker tag "$acr" "$name"
  docker rmi "$acr" >/dev/null                          # drops only the ACR name; the layers stay under $name
  echo "pulled   $name"; pulled=$((pulled+1))
done 3< "$list"
echo "pulled $pulled, already present $present"
