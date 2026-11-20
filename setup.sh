#!/usr/bin/env bash
# The two steps of action.yml that are not the Actions cache:
#
#   setup.sh plan      which build this runner needs, the checksum published beside it, and the
#                      folder it goes in (the Actions cache is restored into that folder next)
#   setup.sh install   that build, from the cache or from marqius.com, checked against the
#                      checksum, then put on the PATH, with the names wkhtmltopdf and
#                      wkhtmltoimage when they are asked for
#
# Both run on Linux and macOS runners (and in Git Bash, for when Windows runners are supported)
# and take their settings from the environment action.yml gives them. MARQIUS_DOWNLOAD names another
# place to download from, such as a mirror inside a firewall, as it does for the installers on
# marqius.com. Nothing is sent anywhere but the download requests.
set -euo pipefail

BASE="${MARQIUS_DOWNLOAD:-https://marqius.com/download/marqius-wkhtmltopdf}"
BASE="${BASE%/}"
AGENT="setup-marqius-wkhtmltopdf/1 (+https://github.com/marqiushq/setup-marqius-wkhtmltopdf)"

# Files and folders of this step's own, taken away when it ends, however it ends
LEFTOVERS=()
trap 'rm -rf ${LEFTOVERS[@]+"${LEFTOVERS[@]}"}' EXIT

# An error that GitHub shows on the run's summary page, and the end of the step
fail() {
    echo "::error title=setup-marqius-wkhtmltopdf::$*"
    exit 1
}

# A value for the steps after this one
output() {
    if [ -n "${GITHUB_OUTPUT:-}" ]; then
        echo "$1=$2" >> "$GITHUB_OUTPUT"
    else
        echo "$1=$2"
    fi
}

# Git Bash works with /c/... paths; GitHub, PowerShell and the program's users with C:\...
on_windows() { [ "${RUNNER_OS:-}" = Windows ] || [ "${OS:-}" = Windows_NT ]; }
as_unix() { if on_windows && command -v cygpath > /dev/null; then cygpath -u "$1"; else printf '%s\n' "$1"; fi; }
as_windows() { if on_windows && command -v cygpath > /dev/null; then cygpath -w "$1"; else printf '%s\n' "$1"; fi; }
# C:/... on Windows: a path that bash, PowerShell and cmd all accept
as_portable() { if on_windows && command -v cygpath > /dev/null; then cygpath -m "$1"; else printf '%s\n' "$1"; fi; }

sha256_of() {
    if command -v sha256sum > /dev/null; then
        sha256sum "$1" | cut -c1-64
    elif command -v shasum > /dev/null; then
        shasum -a 256 "$1" | cut -c1-64
    else
        openssl dgst -sha256 -r "$1" | cut -c1-64
    fi
}

# fetch URL FILE: 0 when the file came, 4 when the address does not exist, 1 when there was no
# good answer after five tries (45 seconds of waiting in all)
fetch() {
    local url="$1" out="$2" code tries=1 wait=3
    local only=(--proto '=https' --proto-redir '=https')
    case "$url" in
        file://*) cp "${url#file://}" "$out" 2> /dev/null && return 0 || return 4 ;;
        http://*) only=() ;; # a mirror named in MARQIUS_DOWNLOAD
    esac
    while :; do
        code="$(curl --silent --show-error --location ${only[@]+"${only[@]}"} --user-agent "$AGENT" \
            --connect-timeout 20 --max-time 300 --output "$out" --write-out '%{http_code}' "$url")" || true
        case "$code" in
            200) return 0 ;;
            404 | 410) return 4 ;;
        esac
        [ "$code" = 000 ] && code="no answer"
        if [ "$tries" -ge 5 ]; then
            echo "$url: $code, $tries times"
            return 1
        fi
        echo "$url: $code; trying again in $wait seconds"
        sleep "$wait"
        tries=$((tries + 1))
        wait=$((wait * 2))
    done
}

# NAMES: true when the names wkhtmltopdf and wkhtmltoimage are asked for
read_names() {
    case "$(printf '%s' "${INPUT_WKHTMLTOPDF_NAMES:-false}" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')" in
        true) NAMES=true ;;
        false | '') NAMES=false ;;
        *) fail "wkhtmltopdf-names is true or false, not '${INPUT_WKHTMLTOPDF_NAMES}'" ;;
    esac
}

plan() {
    local os arch file program=marqius-wkhtmltopdf want version sum other rc latest tmp folder

    read_names # a mistake in the inputs stops the step before anything is downloaded
    os="${RUNNER_OS:-}"
    arch="${RUNNER_ARCH:-}"
    if [ -z "$os" ]; then # run by hand, outside GitHub Actions
        case "$(uname -s)" in Linux) os=Linux ;; Darwin) os=macOS ;; MINGW* | MSYS* | CYGWIN*) os=Windows ;; esac
        case "$(uname -m)" in x86_64 | amd64) arch=X64 ;; aarch64 | arm64) arch=ARM64 ;; esac
    fi
    case "$os:$arch" in
        Linux:X64) file=marqius-wkhtmltopdf-linux-x86_64 arch=x64 ;;
        Linux:ARM64) file=marqius-wkhtmltopdf-linux-arm64 arch=arm64 ;;
        macOS:ARM64) file=marqius-wkhtmltopdf-macos-arm64 arch=arm64 ;;
        macOS:X64) fail "This runner is an Intel Mac, and the macOS build of marqius-wkhtmltopdf is for Apple silicon: use runs-on: macos-latest (or macos-15, macos-26). For Intel Macs, write to hello@marqius.com" ;;
        Windows:*) fail "Windows runners are not supported yet: use a Linux runner (runs-on: ubuntu-latest or ubuntu-24.04-arm) or a macOS one (runs-on: macos-latest). To hear when Windows runners are, write to hello@marqius.com" ;;
        *) fail "marqius-wkhtmltopdf has no build for ${os:-this system} on ${arch:-this processor}: it runs on Linux (x86-64 and ARM64) and macOS (Apple silicon)" ;;
    esac

    tmp="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/marqius.XXXXXX")"
    LEFTOVERS+=("$tmp")

    want="$(printf '%s' "${INPUT_VERSION:-latest}" | tr -d '[:space:]')"
    want="${want#v}"
    [ -n "$want" ] || want=latest
    if [ "$want" = latest ]; then
        fetch "$BASE/latest" "$tmp/latest" || fail "Could not read the latest version from $BASE/latest"
        version="$(tr -d '[:space:]' < "$tmp/latest")"
        [[ "$version" =~ ^[0-9]+(\.[0-9]+){1,3}$ ]] || fail "$BASE/latest does not hold a version"
    else
        version="$want"
        [[ "$version" =~ ^[0-9]+(\.[0-9]+){1,3}$ ]] || fail "version is a release such as 0.12.9, or latest, not '${INPUT_VERSION}'"
    fi

    rc=0
    fetch "$BASE/$version/$file.sha256" "$tmp/sum" || rc=$?
    if [ "$rc" = 4 ]; then
        # no build for this runner: is it the version, or only this platform?
        other=marqius-wkhtmltopdf-linux-x86_64
        [ "$file" = "$other" ] && other=marqius-wkhtmltopdf-macos-arm64
        if fetch "$BASE/$version/$other.sha256" "$tmp/other" > /dev/null; then
            fail "marqius-wkhtmltopdf $version has no build for this runner ($file)"
        fi
        latest="$(fetch "$BASE/latest" "$tmp/latest" > /dev/null && tr -d '[:space:]' < "$tmp/latest" || true)"
        fail "There is no marqius-wkhtmltopdf $version${latest:+; the latest is $latest}"
    fi
    [ "$rc" = 0 ] || fail "Could not reach $BASE"
    sum="$(cut -c1-64 < "$tmp/sum" | tr '[:upper:]' '[:lower:]')"
    [[ "$sum" =~ ^[0-9a-f]{64}$ ]] || fail "$BASE/$version/$file.sha256 does not hold a checksum"

    folder="$(as_unix "${RUNNER_TOOL_CACHE:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/tool-cache}")/marqius-wkhtmltopdf/$version/$arch"
    echo "marqius-wkhtmltopdf $version for this runner: $file, sha256 $sum"
    output version "$version"
    output file "$file"
    output program "$program"
    output sha256 "$sum"
    output folder "$(as_windows "$folder")"
    output key "marqius-wkhtmltopdf-$version-${file#marqius-wkhtmltopdf-}-${sum:0:16}"
}

install() {
    local folder program part said got source size names other rc
    folder="$(as_unix "$PLAN_FOLDER")"
    program="$folder/$PLAN_PROGRAM"
    mkdir -p "$folder"

    if [ -f "$program" ] && [ "$(sha256_of "$program")" = "$PLAN_SHA256" ]; then
        if [ "${CACHE_HIT:-}" = true ]; then source="from the Actions cache"; else source="already on this runner"; fi
        output downloaded false
    else
        if [ -f "$program" ]; then
            echo "The copy in $(as_portable "$folder") does not match the published checksum: downloading it again"
        fi
        part="$program.$$.part"
        LEFTOVERS+=("$part")
        rc=0
        fetch "$BASE/$PLAN_VERSION/$PLAN_FILE" "$part" || rc=$?
        [ "$rc" = 0 ] || fail "Could not download $PLAN_FILE $PLAN_VERSION from $BASE"
        got="$(sha256_of "$part")"
        if [ "$got" != "$PLAN_SHA256" ]; then
            fail "The download of $PLAN_FILE $PLAN_VERSION does not match the checksum published beside it, so it was not installed (published $PLAN_SHA256, downloaded $got)"
        fi
        mv -f "$part" "$program"
        size="$(wc -c < "$program" | tr -d ' ')"
        source="downloaded from ${BASE%%/download/*} ($((size / 1048576)) MB)"
        output downloaded true
    fi
    chmod 755 "$program"
    said="$("$program" --version 2>&1)" || fail "marqius-wkhtmltopdf $PLAN_VERSION does not start on this runner: $said"
    case "$said" in
        "marqius-wkhtmltopdf $PLAN_VERSION"*) ;;
        *) fail "The program says '$said', not marqius-wkhtmltopdf $PLAN_VERSION" ;;
    esac
    echo "marqius-wkhtmltopdf $PLAN_VERSION, $source, checksum verified"
    echo "  $(as_portable "$program")"

    read_names
    if [ "$NAMES" = true ]; then
        names="$(as_unix "${RUNNER_TEMP:-${TMPDIR:-/tmp}}")/marqius-wkhtmltopdf-names"
        other="$(command -v wkhtmltopdf || true)"
        case "$("$other" -V 2>&1 || true)" in *marqius-wkhtmltopdf*) other="" ;; esac # this action's, from an earlier step
        rm -rf "$names"
        mkdir -p "$names"
        said="$("$program" install "$names" 2>&1)" || fail "marqius-wkhtmltopdf install could not give it the names wkhtmltopdf and wkhtmltoimage: $said"
        case "$("$names/wkhtmltopdf" -V 2>&1)" in
            *"marqius-wkhtmltopdf $PLAN_VERSION"*) ;;
            *) fail "wkhtmltopdf in $(as_portable "$names") does not run marqius-wkhtmltopdf $PLAN_VERSION" ;;
        esac
        echo "  wkhtmltopdf and wkhtmltoimage run it, from $(as_portable "$names")"
        if [ -n "$other" ]; then
            echo "  the wkhtmltopdf already at $(as_portable "$other") stays where it is, behind these names on the PATH"
        fi
        if [ -n "${GITHUB_PATH:-}" ]; then as_windows "$names" >> "$GITHUB_PATH"; fi
    fi
    if [ -n "${GITHUB_PATH:-}" ]; then as_windows "$folder" >> "$GITHUB_PATH"; fi
    output path "$(as_portable "$program")"
}

case "${1:-}" in
    plan) plan ;;
    install) install ;;
    *)
        echo "usage: setup.sh plan|install (the steps of action.yml)" >&2
        exit 2
        ;;
esac
