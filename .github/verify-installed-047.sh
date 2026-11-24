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
old=SparkHomeVideoServer-braswell-0.4.7.spk
curl -fsSL --max-time 30 "https://github.com/$GH_REPO/releases/download/v0.4.7/$old" -o "$work/$old"
printf '%s  %s\n' f5101b3c4093d7093e6d6efdfae02eb9b0479ab7edb59319e7a89ffa740f7f44 "$work/$old" | sha256sum -c -
tar -xOf "$work/$old" package.tgz | tar -xz -C "$work/bin"
token='spark-release-feed-test-abcdef0123456'
addr=http://127.0.0.1:58097
SPARK_TOKEN="$token" SPARK_MEDIA_ROOT="$work/media" SPARK_LISTEN=127.0.0.1:58097 \
    SYNOPKG_PKGVAR="$work/state" "$work/bin/sparkvideo" > "$work/spark.log" 2>&1 &
pid=$!
link=''
for ((i=0; i<25; ++i)); do
    source=$(curl -sSf -u "spark:$token" "$addr/api/v1/studio/status" 2>/dev/null | 
        jq -er 'select(.version=="0.4.7") | .dsmPackageSource') || source=''
    if [[ -n $source ]]; then
        link=$(curl -fsS --data 'arch=braswell&model=DS916%2B&build=72806&major=7&minor=2&micro=2&language=cht&package_update_channel=stable' "$addr$source" |
            jq -er '.packages[] | select(.package == "SparkHomeVideoServer" and .version == "0.4.8-0012") | .link') || link=''
        if [[ -n $link ]]; then break; fi
    fi
    sleep 2
done
if [[ -z $link ]]; then
    cat "$work/spark.log"
    exit 1
fi
curl -fsS "$link" -o "$work/new.spk"
cmp "$work/new.spk" release-input/SparkHomeVideoServer-braswell-0.4.8.spk
curl -fsS --data 'arch=braswell&build=42661&language=cht' "$addr$source/" |
    jq -e '.packages[0].version == "0.4.8-0012"' >/dev/null
echo 'Installed 0.4.7 advertises the signed 0.4.8 upgrade for DSM 7.1 and 7.2.2.'
