#!/usr/bin/env bash
# Builds the shipped rules pack: strips authoring annotations from
# packages/content_core/assets/example-core/ into assets/generated/example-core/
# (not committed). Pass --check to verify the generated pack is current
# without writing anything. Run from the repository root.
set -euo pipefail

source_dir=packages/content_core/assets/example-core
target_dir=packages/content_core/assets/generated/example-core

dart run tool/bin/strip_annotations.dart "$source_dir" "$target_dir" "$@"
