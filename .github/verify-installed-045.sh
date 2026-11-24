#!/usr/bin/env bash
set -euo pipefail
work=$(mktemp -d)
pid=
cleanup() {
    if [[ -n $pid ]]; then kill "$pid" 2>/dev/null || true; fi
    rm -rf -- "$work"
}
trap cleanup EXIT
mkdir -p "$work/media" "$work/state" "$work/bin"
old=SparkHomeVideoServer-braswell-0.4.5.spk
curl -fsSL --max-time 30 "https://github.com/$GH_REPO/releases/download/v0.4.5/$old" -o "$work/$old"
printf '%s  %s\n' cb2916a61f2137c663ebedf5a190d77da8ac6eac067b816bbf0d3ddc92b83c3c "$work/$old" | sha256sum -c -
tar -xOf "$work/$old" package.tgz | tar -xz -C "$work/bin"
token='spark-release-feed-test-abcdef0123456'
addr=http://127.0.0.1:58097
SPARK_TOKEN="$token" SPARK_MEDIA_ROOT="$work/media" SPARK_LISTEN=127.0.0.1:58097 \
    SYNOPKG_PKGVAR="$work/state" "$work/bin/sparkvideo" > "$work/spark.log" 2>&1 &
pid=$!
link=''
for ((i=0; i<25; ++i)); do
    source=$(curl -sSf -u "spark:$token" "$addr/api/v1/studio/status" 2>/dev/null | 
        jq -er 'select(.version=="0.4.5") | .dsmPackageSource') || source=''
    if [[ -n $source ]]; then
        link=$(curl -fsS --data 'arch=braswell&build=72806&language=cht' "$addr$source" |
            jq -er '.packages[] | select(.package == "SparkHomeVideoServer" and .version == "0.4.6-0010") | .link') || link=''
        if [[ -n $link ]]; then break; fi
    fi
    sleep 2
done
if [[ -z $link ]]; then
    cat "$work/spark.log"
    exit 1
fi
curl -fsS "$link" -o "$work/new.spk"
cmp "$work/new.spk" release-input/SparkHomeVideoServer-braswell-0.4.6.spk
curl -fsS --data 'arch=braswell&build=42661&language=cht' "$addr$source/" |
    jq -e '.packages[0].version == "0.4.6-0010"' >/dev/null
echo 'Installed 0.4.5 advertises the signed 0.4.6 upgrade for DSM 7.1 and 7.2.2.'
