#!/usr/bin/env bash
set -euo pipefail

# Stock let-go 1.13.0 lacks the cancellation behavior used by this project.
# Pin the public source revision until a release includes it.
lg_revision=50786343e5511973d3ad724b1acf83b91c2775f8
case "$(uname -s)/$(uname -m)" in
  Linux/x86_64)
    platform=linux_amd64
    lgx_sha=264c1913940a26394ddc1f4d3ea24acba530351d06bb16d6f27eaf8cb9e850c7 ;;
  Darwin/arm64)
    platform=darwin_arm64
    lgx_sha=eae5ed492e86f78d5080c458cd59aeb32b728816b403a94d84e5f640363e357f ;;
  Darwin/x86_64)
    platform=darwin_amd64
    lgx_sha=1956d6123ccde38b759fd821867409eb6536cdea58e0aef307c2df2adf6a3952 ;;
  *) echo "Unsupported CI platform" >&2; exit 1 ;;
esac

tool_dir="${RUNNER_TEMP:?}/attractor-tools"
mkdir -p "$tool_dir"
cd "$tool_dir"

install_release() {
  local repo="$1" version="$2" archive="$3" checksum="$4"
  curl --fail --location --silent --show-error --retry 3 \
    "https://github.com/$repo/releases/download/v$version/$archive" -o "$archive"
  printf '%s  %s\n' "$checksum" "$archive" | shasum -a 256 -c -
  tar -xzf "$archive"
}

install_release abogoyavlensky/lgx 0.3.2 "lgx_0.3.2_${platform}.tar.gz" "$lgx_sha"
git init -q runtime
git -C runtime fetch --depth=1 https://github.com/nooga/let-go.git "$lg_revision"
git -C runtime checkout --detach FETCH_HEAD
test "$(git -C runtime rev-parse HEAD)" = "$lg_revision"
(
  cd runtime
  go build -trimpath -ldflags="-s -w -X main.commit=$lg_revision" -o "$tool_dir/lg" .
)
test -x "$tool_dir/lg"
test -x "$tool_dir/lgx"
printf '%s\n' "$tool_dir" >> "${GITHUB_PATH:?}"
printf 'LGX_LG=%s/lg\n' "$tool_dir" >> "${GITHUB_ENV:?}"
