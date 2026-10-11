#!/usr/bin/env bash
# Audit a CentOS 8 host against the CIS profile from scap-security-guide and
# write HTML/ARF reports. The SSG content targets RHEL 8, so the first run
# patches the CPE data to make the rules applicable to CentOS (see README).
#
# Usage: sudo ./scan.sh [output_dir]
set -euo pipefail

OUT_DIR="${1:-/tmp/cis-scan}"
PROFILE="xccdf_org.ssgproject.content_profile_cis"
DATASTREAM="/usr/share/xml/scap/ssg/content/ssg-rhel8-ds.xml"
CPE_DIR="/usr/share/openscap/cpe"
CPE_SRC="https://raw.githubusercontent.com/OpenSCAP/openscap/maint-1.3/cpe"
STAMP="$(date +%Y%m%d-%H%M)"

dnf install -y openscap-scanner scap-security-guide

# Without these changes every rule reports "notapplicable" on CentOS.
if [ ! -f "$CPE_DIR/openscap-cpe-dict.xml.dist" ]; then
  for f in openscap-cpe-dict.xml openscap-cpe-oval.xml; do
    cp "$CPE_DIR/$f" "$CPE_DIR/$f.dist"
    curl -fsSL "$CPE_SRC/$f" -o "$CPE_DIR/$f"
  done
  sed -i \
    -e 's|idref="cpe:/o:redhat:enterprise_linux|idref="cpe:/o:centos:centos|g' \
    -e 's|ref_id="cpe:/o:redhat:enterprise_linux|ref_id="cpe:/o:centos:centos|g' \
    /usr/share/xml/scap/ssg/content/ssg-rhel*.xml
fi

mkdir -p "$OUT_DIR"

# oscap exits 2 when any rule fails, which is the expected outcome of an audit.
oscap xccdf eval \
  --oval-results \
  --profile "$PROFILE" \
  --results-arf "$OUT_DIR/arf-$STAMP.xml" \
  --report "$OUT_DIR/report-$STAMP.html" \
  "$DATASTREAM" || [ $? -eq 2 ]

echo "Report: $OUT_DIR/report-$STAMP.html"
echo "ARF:    $OUT_DIR/arf-$STAMP.xml"
