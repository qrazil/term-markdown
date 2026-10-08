#!/usr/bin/env bash
# The markdown app's own tests. Builds, then runs every tests/*.md through the
# program and diffs against its tests/*.html.
#
#   M31_ROOT=/path/to/m31 bash scripts/test.sh          every case
#   M31_ROOT=/path/to/m31 bash scripts/test.sh links    only the cases whose name matches
#
# Where a .html came from: `tests/oracles/reference.py` derives it from Python `commonmark`,
# the spec's reference implementation, except for a case with a `.hand` file
# beside it, which is written by hand and says so.
#
# The `--full` pages are golden files under tests/full/, written by the program
# itself and then read by a person (they are not derived from an oracle: the
# page is this program's own design). After changing the stylesheet or the page
# layout, regenerate them and review the diff:
#
#   UPDATE_GOLDEN=1 M31_ROOT=/path/to/m31 bash scripts/test.sh full
#
# The last check is speed, on a generated megabyte. It is a check that the
# program is not accidentally quadratic, not a benchmark.
#
# See scripts/build.sh's own header for what M31_ROOT (and LANGC, if the compiler
# isn't at its own default) need to point at.
set -uo pipefail
cd "$(dirname "$0")/.."

# The "deep-quote" pathological case below (20,000 nested blockquotes) needs
# more than the runtime's 1 MiB default stack -- see qrazil/m31's own
# runtime/greenthread.h comment on RT_STACK_SIZE for why the default stays
# 1 MiB everywhere else and this app asks for more itself instead. 8 MiB
# matches a typical OS thread's own default stack size, and is plenty of
# margin (empirically, deep-quote passes cleanly at 8 MiB where 1 MiB
# started failing around ~4,500 levels).
export LANG_STACK_SIZE=${LANG_STACK_SIZE:-8388608}

BIN=./markdown
T=tests
filter=${1:-}

bash scripts/build.sh >/dev/null || exit 1

pass=0
fail=0
check() {
    local what=$1 want=$2 got=$3
    if [ "$want" = "$got" ]; then
        printf '\033[32mok\033[0m   %-28s\n' "$what"
        pass=$((pass + 1))
    else
        printf '\033[31mFAIL\033[0m %-28s want [%s] got [%s]\n' "$what" "$want" "$got"
        fail=$((fail + 1))
    fi
}

for md in "$T"/*.md; do
    name=$(basename "$md" .md)
    [ -n "$filter" ] && [[ $name != *$filter* ]] && continue
    want="$T/$name.html"
    if [ ! -e "$want" ]; then
        printf '\033[31mFAIL\033[0m %-20s no expectation (run tests/oracles/reference.py)\n' "$name"
        fail=$((fail + 1))
        continue
    fi
    # Byte for byte, through `cmp`: `$(...)` would strip trailing newlines and
    # the trailing newline is part of what cmark's layout promises.
    if "$BIN" "$md" | cmp -s - "$want"; then
        tag=""
        [ -e "$T/$name.hand" ] && tag=" (hand-written)"
        printf '\033[32mok\033[0m   %-20s%s\n' "$name" "$tag"
        pass=$((pass + 1))
    else
        printf '\033[31mFAIL\033[0m %-20s\n' "$name"
        diff "$want" <("$BIN" "$md") | head -20 | sed 's/^/       /'
        fail=$((fail + 1))
    fi
done

# --- stdin, --full, --out, a missing file: the command line, not the parser --
if [ -z "$filter" ]; then
    check "stdin" "<p>hi</p>" "$(printf '# x\n\nhi\n' | $BIN | tail -1)"
    check "dash is stdin" "<h1>x</h1>" "$(printf '# x\n' | $BIN - )"
    check "--full" "<!doctype html>" "$(printf 'x\n' | $BIN --full | head -1)"
    check "--title" "<title>T &amp; U</title>" \
          "$(printf 'x\n' | $BIN --full --title 'T & U' | sed -n 6p)"
    tmp=$(mktemp)
    $BIN --out "$tmp" "$T/headings.md" >/dev/null
    check "--out" "$(head -1 "$T/headings.html")" "$(head -1 "$tmp")"
    rm -f "$tmp"
    $BIN /nonexistent.md >/dev/null 2>&1
    check "missing file exits 1" "1" "$?"
    $BIN --nosuchoption </dev/null >/dev/null 2>&1
    check "bad option exits 2" "2" "$?"
fi

# --- --full pages: themes, titles, --css, errors ------------------------------
if [ -z "$filter" ] || [ "$filter" = full ]; then
    F=$T/full
    W=$(mktemp -d)

    # golden NAME ARGS...: the program's output with ARGS against $F/NAME.html.
    golden() {
        local name=$1
        shift
        if [ -n "${UPDATE_GOLDEN:-}" ]; then
            "$BIN" "$@" >"$F/$name.html"
            printf 'wrote %s\n' "$F/$name.html"
            return
        fi
        if "$BIN" "$@" | cmp -s - "$F/$name.html"; then
            printf '\033[32mok\033[0m   %-28s\n' "golden $name"
            pass=$((pass + 1))
        else
            printf '\033[31mFAIL\033[0m %-28s\n' "golden $name"
            diff "$F/$name.html" <("$BIN" "$@") | head -20 | sed 's/^/       /'
            fail=$((fail + 1))
        fi
    }
    golden doc.default --full "$F/doc.md"
    golden doc.bulma --full --theme bulma "$F/doc.md"
    golden doc.none --full --theme none "$F/doc.md"
    golden doc.css-url --full --theme none --css 'https://example.com/site.css?v=1&w=2' "$F/doc.md"
    golden doc.css-file --full --theme none --css "$F/extra.css" "$F/doc.md"
    golden doc.bulma-css-url --full --theme bulma --css https://example.com/site.css "$F/doc.md"

    # The default page: one stylesheet of 3-5 KB, inline, and nothing fetched.
    page=$($BIN --full "$F/doc.md")
    css_bytes=$(printf '%s\n' "$page" | sed -n '/^<style>$/,/^<\/style>$/p' | wc -c)
    check "default css is 3-5 KB" "yes" "$([ "$css_bytes" -ge 3000 ] && [ "$css_bytes" -le 5000 ] && echo yes || echo "no ($css_bytes)")"
    check "default head is offline" "0" \
          "$(printf '%s\n' "$page" | sed '/^<\/head>$/q' | grep -Ec '(src|href)="https?:|@import|url\(|<link|<script')"
    check "default has one </style" "1" "$(printf '%s\n' "$page" | grep -c '</style')"
    check "default has dark + print" "yes" \
          "$(printf '%s\n' "$page" | grep -q 'prefers-color-scheme: dark' && printf '%s\n' "$page" | grep -q '@media print' && echo yes || echo no)"
    check "default viewport meta" "1" "$(printf '%s\n' "$page" | grep -c '<meta name="viewport" content="width=device-width, initial-scale=1" />')"
    check "default lang + charset" "2" "$(printf '%s\n' "$page" | grep -Ec '^<html lang="en">$|^<meta charset="utf-8" />$')"
    check "none has no css" "0" "$($BIN --full --theme none "$F/doc.md" | grep -Ec '<style|<link')"
    check "bulma wraps the body" "2" \
          "$($BIN --full --theme bulma "$F/doc.md" | grep -Ec '^<main class="container">$|^<div class="content">$')"
    check "--css file after theme" "yes" \
          "$($BIN --full --css "$F/extra.css" "$F/doc.md" | awk '/^<style>$/{n++} /rebeccapurple/{if (n == 2) ok = 1} END{print (n == 2 && ok) ? "yes" : "no"}')"
    check "--css url after bulma" "yes" \
          "$($BIN --full --theme bulma --css https://example.com/s.css "$F/doc.md" | awk '/bulma.min.css/{a=NR} /example.com\/s.css/{b=NR} END{print (a > 0 && b > a) ? "yes" : "no"}')"
    check "--css url is escaped" '<link rel="stylesheet" href="https://x.test/a.css?b=1&amp;c=%22&#x27;%3C" />' \
          "$($BIN --full --theme none --css 'https://x.test/a.css?b=1&c="'"'"'<' </dev/null | grep '<link')"

    # The default title: --title, else the first level-1 heading as plain
    # text, else the file's name without its extension, else "Document".
    title_of() { grep -o '<title>.*</title>'; }
    check "title: first # heading" '<title>The Quick Guide &amp; &lt;Friends&gt;</title>' \
          "$($BIN --full "$F/doc.md" | title_of)"
    check "title: --title wins" '<title>Mine &amp; yours</title>' \
          "$($BIN --full --title 'Mine & yours' "$F/doc.md" | title_of)"
    check "title: empty --title" '<title>The Quick Guide &amp; &lt;Friends&gt;</title>' \
          "$($BIN --full --title '' "$F/doc.md" | title_of)"
    check "title: file stem" '<title>no-h1</title>' "$($BIN --full "$F/no-h1.md" | title_of)"
    mkdir -p "$W/dir.d"
    printf 'text\n' >"$W/dir.d/notes.v2.md"
    check "title: stem of a.b.md" '<title>notes.v2</title>' "$($BIN --full "$W/dir.d/notes.v2.md" | title_of)"
    printf 'text\n' >"$W/noext"
    check "title: no extension" '<title>noext</title>' "$($BIN --full "$W/noext" | title_of)"
    check "title: stdin, no heading" '<title>Document</title>' "$(printf 'x\n' | $BIN --full | title_of)"
    check "title: stdin, heading" '<title>From stdin</title>' "$(printf '# From stdin\n' | $BIN --full - | title_of)"
    check "title: setext heading" '<title>Setext one</title>' "$(printf 'Setext one\n==========\n' | $BIN --full | title_of)"
    check "title: image alt" '<title>logo Site</title>' "$(printf '# ![logo](l.png) Site\n' | $BIN --full | title_of)"
    check "title: code and links" '<title>a b c</title>' "$(printf '# `a` [b](/u) **c**\n' | $BIN --full | title_of)"
    check "title: escaped once" '<title>a &amp;amp; b &quot;q&quot; &#x27;s&#x27;</title>' \
          "$(printf '# a &amp; b "q" '"'"'s'"'"'\n' | $BIN --full | title_of)"
    check "title: skips empty h1" '<title>Real</title>' "$(printf '#\n\n# Real\n' | $BIN --full | title_of)"
    check "title: reference link" '<title>See the docs</title>' \
          "$(printf '# See [the docs][d]\n\n[D]: /x\n' | $BIN --full | title_of)"
    check "only definitions: empty" "0" "$(printf '[a]: /x\n' | $BIN | wc -c)"
    check "title: h2 is not a title" '<title>Document</title>' "$(printf '## Not it\n' | $BIN --full | title_of)"

    # Errors. Nothing is written when the page cannot be built.
    err=$($BIN --full --css /nonexistent.css "$F/doc.md" 2>&1 >"$W/out.html")
    code=$?
    check "--css missing: exit" "1" "$code"
    check "--css missing: message" "markdown: --css /nonexistent.css: no such file" "$err"
    check "--css missing: no output" "no" "$([ -s "$W/out.html" ] && echo yes || echo no)"
    $BIN --full --css /nonexistent.css --out "$W/never.html" "$F/doc.md" >/dev/null 2>&1
    check "--css missing: no --out file" "no" "$([ -e "$W/never.html" ] && echo yes || echo no)"
    mkdir -p "$W/adir"
    $BIN --full --css "$W/adir" "$F/doc.md" >/dev/null 2>&1
    check "--css a directory: exit" "1" "$?"
    printf 'a { color: red }\n</style><script>alert(1)</script>\n' >"$W/evil.css"
    err=$($BIN --full --css "$W/evil.css" "$F/doc.md" 2>&1 >/dev/null)
    check "--css </style: exit" "1" "$?"
    check "--css </style: message" "yes" "$([[ $err == *"contains </style"* ]] && echo yes || echo no)"
    printf '/* x */ </STYLE >\n' >"$W/evil2.css"
    $BIN --full --css "$W/evil2.css" "$F/doc.md" >/dev/null 2>&1
    check "--css </STYLE: exit" "1" "$?"
    printf '\xff\xfe\n' >"$W/binary.css"
    $BIN --full --css "$W/binary.css" "$F/doc.md" >/dev/null 2>&1
    check "--css not UTF-8: exit" "1" "$?"
    err=$($BIN --full --theme fancy "$F/doc.md" 2>&1 >/dev/null)
    check "--theme bad: exit" "2" "$?"
    check "--theme bad: message" "markdown: --theme fancy: expected default, bulma or none" "$err"
    $BIN --full --css https://a/x.css --css https://b/y.css "$F/doc.md" >/dev/null 2>&1
    check "--css twice: exit" "2" "$?"
    $BIN --full -theme none "$F/doc.md" >/dev/null 2>&1
    check "-theme (one dash): exit" "2" "$?"
    check "--theme=none" "$($BIN --full --theme none "$F/doc.md" | md5sum)" \
          "$($BIN --full --theme=none "$F/doc.md" | md5sum)"

    # A fragment has no page and no theme: the flags change nothing without --full.
    for md in mixed tables links; do
        check "fragment $md ignores theme" "$($BIN "$T/$md.md" | md5sum)" \
              "$($BIN --theme bulma --css https://x.test/a.css --title T "$T/$md.md" | md5sum)"
    done
    rm -rf "$W"
fi

# --- differential fuzz, when the oracle is installed -------------------------
if [ -z "$filter" ] && python3 -c "import commonmark" 2>/dev/null; then
    for seed in 1 2 3 4; do
        if out=$(python3 tests/oracles/fuzz.py "$seed" 250) && [[ $out == *"0 mismatched, 0 crashed" ]]; then
            printf '\033[32mok\033[0m   %-20s %s\n' "fuzz seed $seed" "$out"
            pass=$((pass + 1))
        else
            printf '\033[31mFAIL\033[0m %-20s\n' "fuzz seed $seed"
            echo "$out" | head -20 | sed 's/^/       /'
            fail=$((fail + 1))
        fi
    done
else
    [ -z "$filter" ] && echo "skip fuzz: python3 -m pip install commonmark"
fi

# --- pathological inputs -----------------------------------------------------
#
# Not correctness: these are the shapes that turn a parser quadratic or
# overflow its stack. 50 000 unmatched `[` used to take 4.5 seconds, because
# every one of them searched forward for a `]` that was not there; the
# bracket map in `MD_inlines.brackets` is why it is 7 ms now. The generous
# bounds are so this fails on an algorithm, not on a slow machine.
if [ -z "$filter" ]; then
    P=$(mktemp -d)
    python3 - "$P" <<'PY'
import sys
d = sys.argv[1]
open(d + "/deep-quote.md", "w").write("> " * 20000 + "hi\n")
open(d + "/deep-list.md", "w").write("".join("  " * i + "- item\n" for i in range(400)))
open(d + "/many-delims.md", "w").write("*a " * 20000 + "\n")
open(d + "/long-line.md", "w").write("x" * 2000000 + "\n")
open(d + "/backticks.md", "w").write("`" * 50000 + "\n")
open(d + "/brackets.md", "w").write("[" * 50000 + "\n")
open(d + "/images.md", "w").write("![" * 20000 + "\n")
# Link reference definitions: the pre-pass and the lookups must stay linear.
open(d + "/defs-one-paragraph.md", "w").write("".join("[d%d]: /u%d\n" % (i, i) for i in range(20000)) + "\n[d19999] [d0]\n")
open(d + "/defs-paragraphs.md", "w").write("".join("[d%d]: /u%d \"t\"\n\n" % (i, i) for i in range(20000)) + "[d19999] [d0]\n")
open(d + "/refs-many.md", "w").write("[x]: /x\n\n" + "[x] [x][] [y][x] ![x] " * 10000 + "\n")
open(d + "/refs-unmatched.md", "w").write("[x]: /x\n\n" + "[nope] [a][b] ![c][d] " * 10000 + "\n")
open(d + "/refs-nested.md", "w").write("[x]: /x\n\n" + "[" * 5000 + "x" + "]" * 5000 + "\n")
open(d + "/refs-same-label.md", "w").write("[x]: /x\n" * 20000 + "\n[x]\n")
open(d + "/refs-long-label.md", "w").write("[" + "a " * 20000 + "]: /x\n\n[" + "a " * 20000 + "]\n")
PY
    for p in "$P"/*.md; do
        name=$(basename "$p" .md)
        start=$(date +%s%N)
        if ! "$BIN" "$p" >/dev/null 2>&1; then
            printf '\033[31mFAIL\033[0m %-20s exited non-zero\n' "pathological $name"
            fail=$((fail + 1))
            continue
        fi
        ms=$(( ($(date +%s%N) - start) / 1000000 ))
        if [ "$ms" -lt 2000 ]; then
            printf '\033[32mok\033[0m   %-20s %s ms\n' "pathological $name" "$ms"
            pass=$((pass + 1))
        else
            printf '\033[31mFAIL\033[0m %-20s %s ms -- something is quadratic\n' "pathological $name" "$ms"
            fail=$((fail + 1))
        fi
    done
    rm -rf "$P"
fi

# --- speed -------------------------------------------------------------------
if [ -z "$filter" ]; then
    big=$(mktemp /tmp/mdbig.XXXXXX.md)
    python3 - "$big" <<'PY'
import sys
one = """## Section

A paragraph with *emphasis*, **strong**, `code` and a [link](/a/b?c=1&d=2).
Another line of the same paragraph, with some non-ASCII: café 中文 👍.

- item one
- item two
  - nested item

> a quote

```c
int main(void) { return 0; }
```

"""
with open(sys.argv[1], "w") as f:
    while f.tell() < 1024 * 1024:
        f.write(one)
PY
    bytes=$(wc -c <"$big")
    start=$(date +%s%N)
    out=$($BIN "$big" | wc -c)
    ms=$(( ($(date +%s%N) - start) / 1000000 ))
    rm -f "$big"
    if [ "$ms" -lt 5000 ]; then
        printf '\033[32mok\033[0m   %-20s %s bytes in -> %s bytes out, %s ms\n' \
               "1 MB document" "$bytes" "$out" "$ms"
        pass=$((pass + 1))
    else
        printf '\033[31mFAIL\033[0m %-20s %s ms for %s bytes\n' "1 MB document" "$ms" "$bytes"
        fail=$((fail + 1))
    fi
fi

echo "── $pass passed, $fail failed"
[ $fail -eq 0 ]
