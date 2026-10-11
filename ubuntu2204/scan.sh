#!/usr/bin/env bash
# Audit an Ubuntu 22.04 host against the CIS Level 1 Server profile with USG
# and write HTML/ARF reports. Requires an attached Ubuntu Pro subscription
# with USG enabled (see README).
#
# Usage: sudo ./scan.sh [output_dir]
set -euo pipefail

OUT_DIR="${1:-/tmp/cis-scan}"
PROFILE="xccdf_org.ssgproject.content_profile_cis_level1_server"
DATASTREAM="/usr/share/ubuntu-scap-security-guides/1/benchmarks/ssg-ubuntu2204-ds.xml"
STAMP="$(date +%Y%m%d-%H%M)"

mkdir -p "$OUT_DIR"

# oscap exits 2 when any rule fails, which is the expected outcome of an audit.
oscap xccdf eval \
  --profile "$PROFILE" \
  --results-arf "$OUT_DIR/arf-$STAMP.xml" \
  --report "$OUT_DIR/report-$STAMP.html" \
  "$DATASTREAM" || [ $? -eq 2 ]

echo "Report: $OUT_DIR/report-$STAMP.html"
echo "ARF:    $OUT_DIR/arf-$STAMP.xml"
