#!/usr/bin/env bash
# Builds the generated diagnostic pack (example and diagnostic content, never
# part of the final demo) into
# packages/content_core/assets/generated/diagnostic-demo/ (not committed).
# Pass --check to verify it is current without writing it (the core pack is still rebuilt first). Run from the
# repository root; it builds the core pack first.
set -euo pipefail

bash tool/build_pack.sh >/dev/null  # the core pack is always rebuilt first
dart run tool/bin/build_diagnostic_pack.dart \
  packages/content_core/assets/generated/example-core \
  packages/content_core/diagnostic/overlay \
  packages/content_core/assets/generated/diagnostic-demo "$@"
