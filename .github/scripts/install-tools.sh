#!/usr/bin/env bash
set -euo pipefail

# Keep these releases aligned with lgx.edn and the documented test runner.
case "$(uname -s)/$(uname -m)" in
  Linux/x86_64)
    platform=linux_amd64
    lg_sha=c3f5b6e0b7c1236e4dcb44759cfc7c30e1bd39d34a9999422c34673c2feacd78
    lgx_sha=264c1913940a26394ddc1f4d3ea24acba530351d06bb16d6f27eaf8cb9e850c7 ;;
  Darwin/arm64)
    platform=darwin_arm64
    lg_sha=ce25565d703836cb5587ebcbb369e889deb4648211b12e83eafa32f02dd247d0
    lgx_sha=eae5ed492e86f78d5080c458cd59aeb32b728816b403a94d84e5f640363e357f ;;
  Darwin/x86_64)
    platform=darwin_amd64
    lg_sha=3147fbd244bfb127434349fe9309ee48606f61d59fc19fc989879f2fa12d0f05
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

install_release nooga/let-go 1.13.0 "let-go_1.13.0_${platform}.tar.gz" "$lg_sha"
install_release abogoyavlensky/lgx 0.3.2 "lgx_0.3.2_${platform}.tar.gz" "$lgx_sha"
test -x "$tool_dir/lg"
test -x "$tool_dir/lgx"
printf '%s\n' "$tool_dir" >> "${GITHUB_PATH:?}"
printf 'LGX_LG=%s/lg\n' "$tool_dir" >> "${GITHUB_ENV:?}"
