#!/usr/bin/env bash

set -u

if [[ "$VERSIONCHECK_SOURCE" != 'github' && "$VERSIONCHECK_SOURCE" != 'conda' ]]; then
    echo "Unsupported source '$VERSIONCHECK_SOURCE'; expected github or conda" >&2
    exit 1
fi
if [[ "$VERSIONCHECK_INCLUDE_PRERELEASES" != 'true' \
    && "$VERSIONCHECK_INCLUDE_PRERELEASES" != 'false' ]]; then
    echo 'include-prereleases must be true or false' >&2
    exit 1
fi

command=(
    versioncheck
    "$VERSIONCHECK_SOURCE"
    "$VERSIONCHECK_PACKAGE"
    --current "$VERSIONCHECK_CURRENT_VERSION"
    --format json
)

if [[ -n "$VERSIONCHECK_VERSION_PATTERN" ]]; then
    command+=(--version-pattern "$VERSIONCHECK_VERSION_PATTERN")
fi
if [[ "$VERSIONCHECK_INCLUDE_PRERELEASES" == 'true' ]]; then
    command+=(--include-prereleases)
fi

if [[ "$VERSIONCHECK_SOURCE" == 'conda' ]]; then
    while IFS= read -r channel; do
        channel="${channel#"${channel%%[![:space:]]*}"}"
        channel="${channel%"${channel##*[![:space:]]}"}"
        if [[ -n "$channel" ]]; then
            command+=(--channel "$channel")
        fi
    done < <(printf '%s' "$VERSIONCHECK_CHANNELS" | tr ',' '\n')

    while IFS= read -r subdir; do
        subdir="${subdir#"${subdir%%[![:space:]]*}"}"
        subdir="${subdir%"${subdir##*[![:space:]]}"}"
        if [[ -n "$subdir" ]]; then
            command+=(--subdir "$subdir")
        fi
    done < <(printf '%s' "$VERSIONCHECK_SUBDIRS" | tr ',' '\n')
fi

report_file="$(mktemp)"
trap 'rm -f "$report_file"' EXIT

set +e
"${command[@]}" > "$report_file"
exit_code=$?
set -e

python3 -c '
import json
import sys

report_path, result_path, exit_code = sys.argv[1:]

try:
    with open(report_path, encoding="utf-8") as report_file:
        report = json.load(report_file)
    results = report["results"]
    if not isinstance(results, list) or len(results) != 1:
        raise ValueError("expected exactly one result")
    result = results[0]
    if not isinstance(result, dict):
        raise TypeError("result is not an object")
    status = result.get("status") or ""
    latest_version = result.get("latest_version") or ""
    message = result.get("message") or ""
    candidates = result.get("candidates", [])
    if not isinstance(candidates, list):
        raise TypeError("candidates is not an array")
    upstream_url = next(
        (
            candidate.get("url") or ""
            for candidate in candidates
            if isinstance(candidate, dict)
            if candidate.get("normalized_version") == latest_version
        ),
        "",
    )
except (json.JSONDecodeError, KeyError, TypeError, ValueError) as error:
    status = ""
    latest_version = ""
    message = f"Could not parse VersionCheck report: {error}"
    upstream_url = ""

values = {
    "exit_code": int(exit_code),
    "status": status,
    "latest_version": latest_version,
    "message": message,
    "upstream_url": upstream_url,
}
with open(result_path, "w", encoding="utf-8") as result_file:
    json.dump(values, result_file)
' "$report_file" "$VERSIONCHECK_RESULT_PATH" "$exit_code"

# The CLI uses 1 to indicate an available update. Preserve all expected exit
# codes as outputs so the outer composite action can interpret them.
if [[ "$exit_code" -gt 2 ]]; then
    exit "$exit_code"
fi
