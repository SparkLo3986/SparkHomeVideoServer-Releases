#!/usr/bin/env bash
set -euo pipefail
work=$(mktemp -d)
pid=
cleanup() {
    if [[ -n $pid ]]; then kill "$pid" 2>/dev/null || true; fi
    rm -rf -- "$work"
}
trap cleanup EXIT
mkdir -p "$work/media" "$work/state" "$work/payload"
tar -xOf release-input/SparkHomeVideoServer-braswell-0.4.5.spk package.tgz | tar -xz -C "$work/payload"
token='fixture-token-for-ci-local-000000000001'
address=http://127.0.0.1:58097
SPARK_TOKEN="$token" SPARK_MEDIA_ROOT="$work/media" SPARK_LISTEN=127.0.0.1:58097     SYNOPKG_PKGVAR="$work/state" "$work/payload/sparkvideo" > "$work/server.log" 2>&1 &
pid=$!
source=
for ((i=0; i<40; ++i)); do
    source=$(curl -fsS -H "Authorization: Bearer $token" "$address/api/v1/studio/status" 2>/dev/null | jq -er .dsmPackageSource) || source=
    if [[ -n $source ]]; then
        link=$(curl -fsS --data 'arch=braswell&build=72806&language=cht' "$address$source/" |
            jq -er '.packages[] | select(.version=="0.4.5-0009" and .package=="SparkHomeVideoServer") | .link') || link=
        if [[ -n $link ]]; then break; fi
    fi
    sleep 2
done
if [[ -z ${link:-} ]]; then
    cat "$work/server.log"
    exit 1
fi
curl -fsS "$link" -o "$work/download.spk"
cmp "$work/download.spk" release-input/SparkHomeVideoServer-braswell-0.4.5.spk
curl -fsS "$address$source?arch=braswell&build=42661" |
    jq -e '.packages | length == 1' >/dev/null
curl -fsS "$address$source?arch=armada38x&build=72806" |
    jq -e '.packages == []' >/dev/null
printf 'Live release, DSM POST catalog, and byte-for-byte SPK download verified.\n'
raw=https://raw.githubusercontent.com/SparkLo3986/SparkHomeVideoServer-Releases/publish-spk-0.4.5/release-input/manifest.json
printf 'Raw GitHub GET: '
curl --silent --show-error --output /dev/null --write-out '%{http_code}\n' "$raw"
printf 'Raw GitHub POST: '
curl --silent --show-error --output /dev/null --write-out '%{http_code}\n' --data 'arch=braswell&build=72806' "$raw"
