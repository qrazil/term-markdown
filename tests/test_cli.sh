#!/usr/bin/env bash
# markdown's command line: Oro's grammar (m31's docs/cli-conventions.md): every
# option in its long and short forms (--out, --o), the defaults, Oro's refusals
# (-h, -o, help, a lone --), the generated --help, --version and --completions.
#
#   M31_ROOT=/path/to/m31 bash tests/test_cli.sh          (builds ./markdown)
#   MARKDOWN_BIN=./markdown bash tests/test_cli.sh        (uses a built one)
#
# macOS-safe: bash 3.2, BSD tools, mktemp, no GNU timeout, no md5sum.
set -uo pipefail
cd "$(dirname "$0")/.."

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
pass=0
fail=0
note() { printf '\033[32mok\033[0m   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '\033[31mFAIL\033[0m %s\n' "$1"; shift; printf '%s\n' "$@" | sed 's/^/     /'; fail=$((fail + 1)); }

BIN=${MARKDOWN_BIN:-}
if [ -z "$BIN" ]; then
    if ! bash scripts/build.sh >"$WORK/build.log" 2>&1; then
        bad "build" "$(tail -5 "$WORK/build.log")"
        exit 1
    fi
    BIN=./markdown
fi
ABS=$(cd "$(dirname "$BIN")" && pwd)/$(basename "$BIN")

printf '# Title\n\nhello *world*\n' >"$WORK/doc.md"
cp "$WORK/doc.md" "$WORK/-dash.md"

# run ARGS... -> $out $err $code. Standard input is /dev/null unless $stdin is a file.
run() {
    "$BIN" "$@" >"$WORK/out" 2>"$WORK/err" <"${stdin:-/dev/null}"
    code=$?
    out=$(cat "$WORK/out")
    err=$(cat "$WORK/err")
}
expect() {
    local label=$1 want=$2 so=${3:-} se=${4:-}
    if [ "$code" != "$want" ]; then
        bad "$label" "exit $code, want $want" "stdout: $out" "stderr: $err"
    elif [ -n "$so" ] && [[ "$out" != *"$so"* ]]; then
        bad "$label" "stdout lacks: $so" "stdout: $out"
    elif [ -n "$se" ] && [[ "$err" != *"$se"* ]]; then
        bad "$label" "stderr lacks: $se" "stderr: $err"
    else
        note "$label"
    fi
}
same() {
    if [ "$2" = "$3" ]; then note "$1"; else bad "$1" "[$2]" "[$3]"; fi
}

# --- help, version, completions ---------------------------------------------------
run --help;  expect "--help" 0 "usage: markdown [options] [<file>]"
for want in "--f, --full" "--t, --title TEXT" "--theme NAME" "--css URL|PATH" "--o, --out PATH" "--w, --watch" \
    "--watch-limit N" "--help" "--version" "--completions SHELL" "(default -)" "exit status:"; do
    run --help
    if [[ "$out" == *"$want"* ]]; then note "--help lists: $want"; else bad "--help lacks: $want" "$out"; fi
done
run --version; expect "--version" 0 "markdown 0."
run --completions bash; expect "--completions bash" 0 "complete -o filenames -F _markdown_complete markdown"
if printf '%s\n' "$out" | bash -n 2>"$WORK/syntax"; then note "--completions bash is valid bash"; else bad "bash completion syntax" "$(cat "$WORK/syntax")"; fi
run --completions fish; expect "--completions fish" 0 "complete -c markdown -l out"
run --completions zsh;  expect "--completions zsh" 0 "#compdef markdown"

# --- the same output, whatever the spelling ----------------------------------------
run "$WORK/doc.md"; base=$out
expect "default: a fragment" 0 "<h1>Title</h1>"
run --full "$WORK/doc.md"; full=$out
run --f "$WORK/doc.md"; same "--f is --full" "$full" "$out"
[[ "$full" == *"<html"* ]] && note "--full is a whole document" || bad "--full is not a document" "$full"
run --full --title "My Page" "$WORK/doc.md"; titled=$out
run --f --t "My Page" "$WORK/doc.md"; same "--t is --title" "$titled" "$out"
run --full --title="My Page" "$WORK/doc.md"; same "--title=T" "$titled" "$out"
[[ "$titled" == *"<title>My Page</title>"* ]] && note "--title is the <title>" || bad "--title ignored" "$titled"
run --full --theme none "$WORK/doc.md"; none=$out
run --full --theme=none "$WORK/doc.md"; same "--theme=none" "$none" "$out"
run --full --theme bulma "$WORK/doc.md"; [[ "$out" == *bulma* ]] && note "--theme bulma links Bulma" || bad "--theme bulma" "$out"
run --full --theme default "$WORK/doc.md"; def=$out
run --full "$WORK/doc.md"; same "default theme is the default" "$def" "$out"
printf 'p { color: red; }\n' >"$WORK/site.css"
run --full --theme none --css "$WORK/site.css" "$WORK/doc.md"; [[ "$out" == *"color: red"* ]] && note "--css FILE is inlined" || bad "--css" "$out"

# --- --out: long, equals and short ---------------------------------------------------
for spelling in "--out $WORK/o1.html" "--out=$WORK/o2.html" "--o $WORK/o3.html"; do
    # shellcheck disable=SC2086
    run $spelling "$WORK/doc.md"
    target=$(printf '%s' "$spelling" | sed -e 's/^--out=//' -e 's/^--out //' -e 's/^--o //')
    if [ "$code" = 0 ] && [ "$(cat "$target" 2>/dev/null)" = "$base" ] && [ -z "$out" ]; then note "$spelling writes the file, not stdout"; else bad "$spelling" "exit $code" "$err"; fi
done

# --- operands -------------------------------------------------------------------------
stdin="$WORK/doc.md" run;      same "no operand reads standard input" "$base" "$out"
stdin="$WORK/doc.md" run -;    same "- reads standard input" "$base" "$out"
(cd "$WORK" && "$ABS" ./-dash.md >"$WORK/dd.out" 2>&1 </dev/null; echo $? >"$WORK/dd.rc")
[ "$(cat "$WORK/dd.rc")" = 0 ] && [ "$(cat "$WORK/dd.out")" = "$base" ] && note "a file called -dash.md is passed as ./-dash.md" || bad "./-dash.md" "$(cat "$WORK/dd.out")"
(cd "$WORK" && "$ABS" -dash.md >"$WORK/dd.out" 2>&1 </dev/null; echo $? >"$WORK/dd.rc")
[ "$(cat "$WORK/dd.rc")" = 2 ] && note "-dash.md is a command, refused" || bad "-dash.md" "$(cat "$WORK/dd.out")"

# --- Oro's refusals: stderr, exit 2 ------------------------------------------------------
run -h;               expect "-h is refused" 2 "" "write '--help'"
run -o x "$WORK/doc.md"; expect "-o is a command, refused" 2 "" "takes no commands, and got '-o'"
run help;             expect "help is a file name here (markdown takes a file), not a refusal" 1 "" "help"
run --h;              expect "--h is refused" 2 "" "help has one spelling"
run --;               expect "a lone -- is refused" 2 "" "'--' has no meaning here"
run --ful "$WORK/doc.md";  expect "an abbreviation is suggested, never accepted" 2 "" "did you mean '--full'?"
run --fw "$WORK/doc.md";   expect "shorts do not cluster" 2 "" "short options do not cluster -- write '--f --w'"
run --nonsense "$WORK/doc.md"; expect "an unknown option" 2 "" "unknown option '--nonsense'"
run --theme fancy "$WORK/doc.md"; expect "bad theme" 2 "" "--theme fancy: expected default, bulma or none"
run --out;            expect "--out at the end" 2 "" "'--out' needs a value and is the last argument"
run --out --full "$WORK/doc.md"; expect "--out does not eat an option" 2 "" "starts with a dash"
run --out a --out b "$WORK/doc.md"; expect "--out twice" 2 "" "was given more than once and takes a single value"
run --full=1 "$WORK/doc.md"; expect "--full takes no value" 2 "" "is a flag and takes no value"
run --full --full "$WORK/doc.md"; expect "--full twice" 2 "" "was given more than once"
run "$WORK/doc.md" extra; expect "two operands" 2 "" "unexpected argument 'extra'"
run --watch "$WORK/doc.md"; expect "--watch needs --out" 2 "" "--watch needs --out"
run --watch --out "$WORK/w.html" -; expect "--watch needs a file" 2 "" "needs a file to watch"
run --watch --out "$WORK/doc.md" "$WORK/doc.md"; expect "--watch --out is the input" 2 "" "would overwrite its own source"
[ "$(head -1 "$WORK/doc.md")" = "# Title" ] && note "the input was left untouched" || bad "input clobbered"
run --watch-limit many --watch --out "$WORK/w.html" "$WORK/doc.md"; expect "bad --watch-limit" 2 "" "'--watch-limit' needs a whole number, and got 'many'"
run --watch-limit -1 "$WORK/doc.md"; expect "--watch-limit -1" 2 "" "'--watch-limit' needs a whole number of at least 0"
[ "$(printf '%s\n' "$err" | wc -l | tr -d ' ')" -ge 2 ] && note "usage errors carry the usage line" || bad "usage error shape" "$err"
[ -z "$out" ] && note "usage errors print nothing on stdout" || bad "usage error wrote stdout" "$out"

# --- runtime failures: exit 1 ---------------------------------------------------------------
run /nonexistent.md;  expect "missing input" 1 "" "markdown: /nonexistent.md"
run --out /nonexistent/dir/x.html "$WORK/doc.md"; expect "unwritable output" 1 "" "markdown:"

# --- --watch with a limit builds once and ends ---------------------------------------------
run --watch --watch-limit 1 --out "$WORK/watched.html" "$WORK/doc.md"
if [ "$code" = 0 ] && [ "$(cat "$WORK/watched.html")" = "$base" ]; then note "--watch --watch-limit 1 builds and exits 0"; else bad "--watch --watch-limit 1" "exit $code" "$err"; fi
run --w --watch-limit 1 --o "$WORK/watched2.html" "$WORK/doc.md"
[ "$code" = 0 ] && [ "$(cat "$WORK/watched2.html")" = "$base" ] && note "--w --o: the short forms" || bad "--w --o" "exit $code" "$err"

# --- install.sh ----------------------------------------------------------------
run_sh() {
    sh install.sh "$@" >"$WORK/out" 2>"$WORK/err" </dev/null
    code=$?
    out=$(cat "$WORK/out")
    err=$(cat "$WORK/err")
}
run_sh --help; expect "install.sh --help" 0 "usage: sh install.sh [options] [-uninstall]"
run_sh --version; expect "install.sh --version" 0 "installer"
run_sh -h;     expect "install.sh: -h is refused" 2 "" "write '--help'"
run_sh help;   expect "install.sh: help is refused" 2 "" "write '--help'"
run_sh --;     expect "install.sh: a lone -- is refused" 2 "" "'--' has no meaning here"
run_sh --prefx /x; expect "install.sh: typo suggests" 2 "" "did you mean '--prefix'?"
run_sh -unistall;  expect "install.sh: a mistyped command is suggested" 2 "" "did you mean '-uninstall'?"
run_sh --libc foo; expect "install.sh: bad --libc" 2 "" "needs gnu or musl, and got 'foo'"
run_sh --prefix;   expect "install.sh: --prefix at the end" 2 "" "needs a value and is the last argument"
run_sh extra;  expect "install.sh: an operand" 2 "" "unexpected argument 'extra'"
for spelling in "-uninstall --prefix $WORK/i1" "-u --prefix=$WORK/i2" "-u --p $WORK/i3"; do
    # shellcheck disable=SC2086
    run_sh $spelling
    expect "install.sh $(printf '%s' "$spelling" | sed "s#$WORK#.#g")" 0 "removed"
done
run_sh --uninstall --prefix "$WORK/i4"; expect "install.sh --uninstall (the old spelling) works and warns" 0 "removed" "deprecated"

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
