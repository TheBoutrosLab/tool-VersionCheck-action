# VersionCheck GitHub Action

[![GitHub release](https://img.shields.io/github/v/release/TheBoutrosLab/tool-VersionCheck-action)](https://github.com/TheBoutrosLab/tool-VersionCheck-action/actions/workflows/prepare-release.yaml)

Run [VersionCheck](https://github.com/TheBoutrosLab/tool-version-check) in GitHub Actions workflows to check and report the latest available versions of software tools.

The action reads the latest matching release tag from the repository where it
runs, compares that version with an upstream GitHub repository or Conda
package, and opens an issue when a newer version is available. An existing open
issue for the same package and latest version is reused.

## Usage

The workflow must grant `issues: write` permission so the action can create an
update issue. Check out the repository and all of its tags before running the
action. Disable persisted checkout credentials because VersionCheck does not
need authenticated Git access. The repository must use the default checkout
path so its root is `$GITHUB_WORKSPACE`.

```yaml
---
name: Check for new versions

on:
  schedule:
    - cron: '0 8 * * 1'
  workflow_dispatch:

permissions:
  contents: read
  issues: write

jobs:
  version-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
          fetch-tags: true
          persist-credentials: false

      - uses: TheBoutrosLab/tool-VersionCheck-action@v1
        with:
          source: github
          package: samtools/samtools
```

By default, release tags must use semantic versions prefixed with `v`, such as
`v1.2.3` or `v2.0.0-rc.1`. The `tag-pattern` input accepts a Bash regular
expression. The first capture group is used as the current version. If the
expression has no capture group, the whole match is used:

```yaml
- uses: actions/checkout@v7
  with:
    fetch-depth: 0
    fetch-tags: true
    persist-credentials: false

- uses: TheBoutrosLab/tool-VersionCheck-action@v1
  with:
    source: conda
    package: samtools
    tag-pattern: '^release-(.+)$'
    channels: bioconda
    subdirs: linux-64,noarch
    issue-labels: dependencies
```

The `version-pattern` input is passed to VersionCheck when upstream release or
tag names also need custom version extraction. Set `include-prereleases` to
`true` to include prerelease versions.

The action runs the published `tool-version-check` image as a GitHub Actions
Docker step. The `docker-tag` input selects the image version with a built-in default tracking releases.

The `github-token` input is used only by the host-side issue step and defaults
to the workflow's `github.token`. For authenticated upstream GitHub queries,
provide a separate read-only token through `versioncheck-token`. No token is
passed to the VersionCheck container for Conda queries.

The action provides the following outputs:

- `current-tag`: latest repository tag matching `tag-pattern`
- `current-version`: version extracted from the matching tag
- `latest-version`: latest version reported by VersionCheck
- `update-available`: `true` when the upstream version is newer
- `issue-url`: URL of the new or existing update issue, otherwise empty

## Versioning

Per [GitHub's advice](https://docs.github.com/en/actions/creating-actions/about-custom-actions#using-tags-for-release-management), this repository uses semantic version tags. Full semantic version tags are immutable, while major version tags are updated to the latest compatible release.

Callers should use the latest major version tag for stable, backwards-compatible updates.

## License

Author: Yash Patel

tool-VersionCheck-action is licensed under the GNU General Public License version 2. See the file LICENSE for the terms of the GNU GPL license.

tool-VersionCheck-action provides a GitHub Actions interface for VersionCheck.

Copyright (C) 2026 Sanford Burnham Prebys Medical Discovery Institute ("Boutros Lab")

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
