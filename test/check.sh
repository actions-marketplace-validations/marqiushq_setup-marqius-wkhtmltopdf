#!/usr/bin/env bash
# Checks for .github/workflows/test.yml, one to a step:
#
#   check.sh installed        the program on the PATH and at the output path, at the release wanted
#   check.sh converts         a PDF, a picture and a comparison made with it
#   check.sh names VERSION    wkhtmltopdf and wkhtmltoimage run marqius-wkhtmltopdf VERSION
#   check.sh no-names         wkhtmltopdf, if the runner has one, is not marqius-wkhtmltopdf
#   check.sh pdf FILE...      each file is a PDF
#   check.sh mirror FOLDER    a mirror of marqius.com whose build has one byte more than the build
#                             its checksum was taken from; MARQIUS_DOWNLOAD names it from then on
#   check.sh refused TEXT     the step before failed, nothing was installed, and setup.sh says TEXT
set -euo pipefail

fail() {
    echo "::error::$*"
    exit 1
}

is_pdf() { [ -s "$1" ] && [ "$(head -c 5 "$1")" = "%PDF-" ]; }

case "${1:-}" in
    installed)
        [ "$VERSION" = "$WANT" ] || fail "the output version is '$VERSION', not the latest release, $WANT"
        [ "$(marqius-wkhtmltopdf --version)" = "marqius-wkhtmltopdf $WANT" ] || fail "marqius-wkhtmltopdf on the PATH is not $WANT"
        [ "$("$PROGRAM" --version)" = "marqius-wkhtmltopdf $WANT" ] || fail "the output path $PROGRAM does not run $WANT"
        case "$CACHE_HIT" in true | false) ;; *) fail "cache-hit is '$CACHE_HIT'" ;; esac
        echo "marqius-wkhtmltopdf $WANT at $PROGRAM, from the cache: $CACHE_HIT"
        ;;
    converts)
        printf '<html><body><h1>Invoice 42</h1><p>Total \xe2\x82\xac1,234.50</p></body></html>' > check-invoice.html
        marqius-wkhtmltopdf -q --page-size A4 check-invoice.html check-invoice.pdf
        is_pdf check-invoice.pdf || fail "no PDF was made"
        marqius-wkhtmltopdf wkhtmltoimage -q --width 400 check-invoice.html check-invoice.png
        [ "$(head -c 4 check-invoice.png | od -An -tx1 | tr -d ' \n')" = 89504e47 ] || fail "no PNG was made"
        marqius-wkhtmltopdf compare check-invoice.pdf check-invoice.pdf > /dev/null || fail "compare finds a PDF differs from itself"
        words="$(marqius-wkhtmltopdf compare --words check-invoice.pdf)"
        case "$words" in *1,234.50*) ;; *) fail "the PDF's text does not read back: $words" ;; esac
        echo "A PDF, a PNG and a comparison: all made"
        ;;
    names)
        [ "${VERSION:-$2}" = "$2" ] || fail "the output version is '$VERSION', not $2"
        case "$(wkhtmltopdf -V)" in *"compatible; marqius-wkhtmltopdf $2"*) ;; *) fail "wkhtmltopdf does not run marqius-wkhtmltopdf $2: $(wkhtmltopdf -V)" ;; esac
        case "$(wkhtmltoimage -V)" in *"compatible; marqius-wkhtmltopdf $2"*) ;; *) fail "wkhtmltoimage does not run marqius-wkhtmltopdf $2" ;; esac
        printf '<p>Statement</p>' > check-names.html
        wkhtmltopdf -q check-names.html check-names.pdf
        is_pdf check-names.pdf || fail "wkhtmltopdf made no PDF"
        echo "wkhtmltopdf and wkhtmltoimage run marqius-wkhtmltopdf $2"
        ;;
    no-names)
        if command -v wkhtmltopdf > /dev/null; then
            case "$(wkhtmltopdf -V 2>&1 || true)" in *marqius*) fail "wkhtmltopdf runs marqius-wkhtmltopdf, which was not asked for" ;; esac
            echo "The runner's own wkhtmltopdf is still the one on the PATH"
        else
            echo "No wkhtmltopdf on the PATH, as asked"
        fi
        ;;
    pdf)
        shift
        for f in "$@"; do is_pdf "$f" || fail "$f is not a PDF"; done
        echo "PDFs: $*"
        ;;
    mirror)
        # the latest build and its checksum, as release 9.9.9 so that no cache holds a good copy
        folder="$2"
        version="$(curl -fsSL --retry 5 --retry-all-errors https://marqius.com/download/marqius-wkhtmltopdf/latest | tr -d '[:space:]')"
        file=marqius-wkhtmltopdf-linux-x86_64
        [ "$(uname -m)" = aarch64 ] && file=marqius-wkhtmltopdf-linux-arm64
        mkdir -p "$folder/9.9.9"
        echo 9.9.9 > "$folder/latest"
        curl -fsSL --retry 5 --retry-all-errors -o "$folder/9.9.9/$file" "https://marqius.com/download/marqius-wkhtmltopdf/$version/$file"
        curl -fsSL --retry 5 --retry-all-errors -o "$folder/9.9.9/$file.sha256" "https://marqius.com/download/marqius-wkhtmltopdf/$version/$file.sha256"
        printf '\0' >> "$folder/9.9.9/$file"
        echo "MARQIUS_DOWNLOAD=file://$folder" >> "$GITHUB_ENV"
        echo "A mirror of $file $version, one byte longer than the build its checksum was taken from, in $folder"
        ;;
    refused)
        [ "$OUTCOME" = failure ] || fail "the action did not refuse (its outcome: $OUTCOME)"
        if command -v marqius-wkhtmltopdf > /dev/null; then fail "marqius-wkhtmltopdf was installed all the same"; fi
        # the action's steps again, with the same inputs, to read what they say
        plan="$(mktemp)"
        said="$(GITHUB_OUTPUT="$plan" bash ./setup.sh plan 2>&1 || true)"
        if [ -s "$plan" ]; then
            while IFS='=' read -r key value; do export "PLAN_$(printf '%s' "$key" | tr '[:lower:]' '[:upper:]')=$value"; done < "$plan"
            said="$said
$(GITHUB_OUTPUT=/dev/null GITHUB_PATH=/dev/null bash ./setup.sh install 2>&1 || true)"
        fi
        case "$said" in *"$2"*) ;; *) fail "the message does not say '$2': $said" ;; esac
        echo "Refused, saying: $(printf '%s\n' "$said" | grep -m1 '::error' | sed 's/^::error[^:]*:://')"
        ;;
    *)
        echo "usage: check.sh installed|converts|names VERSION|no-names|pdf FILE...|mirror FOLDER|refused TEXT" >&2
        exit 2
        ;;
esac
