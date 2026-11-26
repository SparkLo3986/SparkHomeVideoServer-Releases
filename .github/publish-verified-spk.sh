#!/usr/bin/env bash
set -euo pipefail

cd release-input
version=$(jq -er '.version | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))' manifest.json)
tag="v$version"
package="SparkHomeVideoServer-braswell-$version.spk"
[[ "$GITHUB_REF_NAME" == "publish-spk-$version" ]]
sha=$(sha256sum "$package" | cut -d' ' -f1)
size=$(stat -c %s "$package")
jq -e --arg sha "$sha" --argjson size "$size"     '.architecture == "braswell" and .sha256 == $sha and .size == $size' manifest.json >/dev/null
openssl pkeyutl -verify -rawin -pubin -inkey legacy.pem -in manifest.json -sigfile manifest.sig
openssl dgst -sha256 -verify rsa.pem -signature manifest.rsa.sig manifest.json
info=$(tar -xOf "$package" INFO)
grep -Fxq 'package="SparkHomeVideoServer"' <<< "$info"
grep -Fxq 'arch="braswell"' <<< "$info"
grep -Fxq 'os_min_ver="7.1-42661"' <<< "$info"
grep -Fq "version=\"$version-" <<< "$info"

release() {
    gh api --paginate "repos/$GH_REPO/releases?per_page=100" --jq ".[] | select(.tag_name == \"$tag\")"
}
verify_assets() {
    local json=$1 file digest length
    for file in "$package" manifest.json manifest.sig manifest.rsa.sig; do
        digest="sha256:$(sha256sum "$file" | cut -d' ' -f1)"
        length=$(stat -c %s "$file")
        jq -e --arg name "$file" --arg digest "$digest" --argjson size "$length"             'any(.assets[]; .state == "uploaded" and .name == $name and .digest == $digest and .size == $size)'             <<< "$json" >/dev/null
    done
}

existing=$(release)
if [[ -n $existing ]] && jq -e '.draft == false' <<< "$existing" >/dev/null; then
    verify_assets "$existing"
    echo "$tag already contains the verified assets."
    exit 0
fi
marker='<!-- spark-verified-spk -->'
if [[ -n $existing ]]; then
    jq -e --arg marker "$marker" '.draft and (.body | contains($marker))' <<< "$existing" >/dev/null
else
    gh release create "$tag" --target main --draft --title "Spark Home Video Server $tag"         --notes "$marker"$'\n\nDSM Package Center source for DS916+ / braswell, DSM 7.1-42661 and later. Shows indexed video dynamic range and audio format badges beneath the poster in movie and episode details.'
fi
gh release upload "$tag" "$package" manifest.json manifest.sig manifest.rsa.sig --clobber
verify_assets "$(release)"
gh release edit "$tag" --draft=false --prerelease=false
release | jq -er 'select(.draft == false and .prerelease == false) | .html_url'
