# `markdown` — a CommonMark subset to HTML

The first real application written in this language. About 2 300 lines across
seven modules, no Rust, no C, and nothing in `lib/` changed to make it fit.
`docs/FRICTION.md` is the other half of the exercise: what the
language made awkward, what the standard library did not have, and what it
did better than the alternatives.

    M31_ROOT=/path/to/m31 LANGC=/path/to/m31c bash scripts/build.sh   # ./markdown
    M31_ROOT=/path/to/m31 LANGC=/path/to/m31c bash scripts/test.sh    # the tests

    markdown README.md                       the HTML fragment, on stdout
    markdown --full --title T in.md --out f  a whole document, to a file
    markdown --full --theme bulma in.md      the same, styled by Bulma
    markdown --full --css site.css in.md     the same, plus your own CSS
    markdown                                 reads standard input
    markdown --help

Note the two dashes on `--out`: `lib/args` reads a single dash as a command
word, so this program's short option is spelled `--o` and `-o` is an error.
The same goes for every option here: `--theme`, never `-theme`.

## `--full`: a page you can open

Without `--full` the output is the HTML fragment and nothing else, byte for
byte what it has always been. With it, the fragment is wrapped in a complete
page: `<!doctype html>`, `<html lang="en">`, the charset and viewport `<meta>`
tags, a `<title>`, the styling, and the body.

| Option | |
|---|---|
| `--title TEXT` | the page's `<title>`, escaped. Without it: the text of the first top-level `#` heading (markup removed, an image contributing its `alt`), else the file name without its extension (`notes.v2.md` is `notes.v2`), else `Document` (standard input). An empty `--title ''` counts as none |
| `--theme default` | the built-in stylesheet, inlined in a `<style>` element. This is the default |
| `--theme bulma` | Bulma 1.x, linked from the jsDelivr CDN, with the body wrapped in `<main class="container"><div class="content">`. This theme needs a network |
| `--theme none` | no CSS at all: the browser's own defaults |
| `--css REF` | one extra stylesheet, after the theme's. An `http://` or `https://` URL becomes a `<link rel="stylesheet">`; anything else is a file, read and inlined in a `<style>` element. Given once |

`--theme`, `--css` and `--title` mean nothing without `--full` and are ignored
there; an unknown `--theme` is a usage error either way (exit 2).

**The default page is self-contained.** The stylesheet is about 3.2 KB, lives
in `MD_theme.m31`, and the page links to nothing and loads nothing: it works
offline, from a file, in an email attachment. It is classless — it styles the
plain elements the renderer already writes, so the fragment gains no
attributes — and it covers a text column of 70 characters at most with side
padding on a phone, a system font stack, a heading scale, `code` and `pre`
(long lines scroll sideways rather than overflow), block quotes, lists, tables
with borders, zebra rows and the column alignment the markdown asked for,
rules, images capped at the column's width, and links. Light and dark are one
set of rules over CSS custom properties, switched by
`prefers-color-scheme`; a `@media print` block turns it black on white and
prints each external link's address after it.

**Bulma.**

    markdown --full --theme bulma in.md --out index.html

Bulma 1.x follows `prefers-color-scheme` itself. Add your own rules after it
with `--css`:

    markdown --full --theme bulma --css tweaks.css in.md --out index.html

**Your own CSS.** `--theme none --css site.css` is a page with only your
stylesheet; `--css https://example.com/site.css` links it instead of reading
it. Whatever is inlined is refused if it contains `</style` (in any case),
which would end the `<style>` element and let the rest run as markup, and a
file that cannot be read or is not UTF-8 stops the program with a message
and exit 1, before anything is written. URLs are escaped for the attribute
they sit in.

## The shape of it

| | |
|---|---|
| `main.m31` | the command line (`lib/args`) and the files (`lib/io`) |
| `MD_blocks.m31` | the block parser: source to a list of `MD_doc.Block` |
| `MD_inlines.m31` | the inline parser: one block's raw text to HTML |
| `MD_render.m31` | the tree to HTML, with cmark's whitespace |
| `MD_theme.m31` | the `--full` page: the embedded stylesheet, the three themes, the head and body |
| `MD_title.m31` | the default `<title>`: first heading, else file stem, else `Document` |
| `MD_doc.m31` | the tree's types alone, so the other three need not import each other |

The block parser is line based and recursive: a container — a block quote, a
list item — strips its own marker off the lines it owns and hands the rest
back to `parse_lines`, so nesting costs one call. Inline content is *not*
parsed there; a block keeps the raw source of its own text and the renderer
parses it. The inline parser is two passes, because CommonMark's emphasis
rules cannot be decided left to right: a scan makes a list of finished HTML
and unresolved `*`/`_` runs, then `emphasis` pairs the runs up.

## What is in

**Blocks.** ATX headings (`#` to `######`, with an optional closing run of
`#`), setext headings (`===`, `---`), thematic breaks (`***`, `---`, `___`),
paragraphs, indented code blocks, fenced code blocks (backticks and tildes,
with an info string that becomes `class="language-…"`), block quotes with
lazy continuation, bullet lists (`-`, `+`, `*`), ordered lists (`1.`, `1)`,
with `start=`), nesting to any depth, and the tight/loose distinction.

**Inlines.** Backslash escapes, code spans (any backtick run length, with the
space-stripping rule), emphasis and strong with `*` and `_` including the
flanking and rule-of-three rules, inline links with `<…>` and bare
destinations, balanced parentheses, and `"…"`/`'…'`/`(…)` titles, images with
plain-text `alt`, URI and email autolinks, hard breaks (two trailing spaces,
or a trailing backslash), soft breaks.

**Escaping.** Text goes through `lib/html.escape`. Link destinations go
through this program's `escape_href`, which reproduces cmark's
`houdini_escape_href` — percent-encoding, `&amp;`, `&#x27;`.

**Tables.** GFM pipe tables, with `:---`, `:---:` and `---:` alignment,
escaped `\|`, and rows padded or cut to the header's width. This is an
extension, not CommonMark, so its expected output is written by hand.

## What is left out, and why

Full CommonMark is a sixty-page specification and matching it was never the
goal. Each of these was left out on purpose:

- **Raw HTML**, block and inline. It is the largest single piece of the spec
  (seven kinds of HTML block, each with its own end condition) and it is the
  piece with the least to teach about the language. `<div>` on a line of its
  own is a paragraph here, with its angle brackets escaped.
- **Entity and numeric character references.** `&copy;` stays `&amp;copy;`.
  Decoding them means shipping HTML5's two-thousand-entry table, which
  `lib/html` refuses to do for exactly the same reason (see `lib/html.m31`,
  "There is no `unescape`").
- **Link reference definitions** and reference, collapsed and shortcut links
  (`[foo]: /url`, `[text][ref]`, `[foo]`). These need a document-wide first
  pass to collect definitions before any inline is parsed. The architecture
  here already allows it — blocks keep their raw text precisely so inlines
  run last — so this is the omission most likely to be filled in.
- **Unicode character classes in the emphasis rules.** Flanking is decided on
  bytes, so every byte of a non-ASCII character is "other", which is what a
  letter is. `é` and `字` behave correctly; `»` and U+00A0 are treated as
  letters where CommonMark would call them punctuation and whitespace.
  `lib/unicode` has `upper`, `fold`, `graphemes`, `nfc` and `width`, but no
  category predicate, and writing one here would mean a private copy of the
  tables.
- **Tabs other than in leading whitespace.** A leading tab expands to the next
  four-column stop; a tab inside a line is content and is left as written.
- **Links inside links.** A `[` inside a link's text is literal, which is
  CommonMark's outcome by a different route.
- **Smart punctuation, footnotes, strikethrough, task lists, front matter.**
  Not in CommonMark, or not wanted.

`tests/divergences.md` and its hand-written `tests/divergences.html` are the
executable version of this list.

## How it is tested

`bash scripts/test.sh` does six things.

1. **The corpus.** `tests/*.md` through the program, diffed against
   `tests/*.html`. Twenty-three cases, chosen for the awkward parts:
   unterminated emphasis, `*a**b*` and `**a*b**`, mixed nested list markers,
   backticks inside fences and fences inside backticks, links with
   parentheses and with angle brackets, non-ASCII and emoji, CRLF endings,
   empty list items, lazy continuation.
2. **The oracle.** Every expectation but two is *derived*, by
   `tests/oracles/reference.py`, from Python `commonmark` — a port of cmark, which is
   CommonMark's own reference implementation. One normalisation is applied
   and it is written out in that file: `'` becomes `&#x27;`, because
   `lib/html.escape` escapes all five characters and cmark escapes four. The
   two hand-written cases (`tables`, `divergences`) say so with a `.hand`
   file beside them.
3. **Differential fuzz.** `tests/oracles/fuzz.py` glues random lines together from a pool
   of awkward fragments and compares against the same oracle: 1 000 documents
   per run, four seeds. This found three real bugs that the fixed corpus did
   not.
4. **The command line.** stdin, `-`, `--full`, `--title`, `--out`, a missing
   file, a bad option.
5. **The `--full` pages.** Golden files in `tests/full/` for each theme, for
   `--css` as a URL and as a file, and for Bulma with a URL after it; the
   default-title rule in a dozen cases; the errors (a missing, unreadable,
   non-UTF-8 or `</style`-carrying `--css` file, an unknown theme, `--css`
   twice); the default page's size and that it fetches nothing; and that a
   fragment is unchanged by the page options. These goldens are written by the
   program and reviewed by eye, not derived from the oracle: regenerate after
   a deliberate change with `UPDATE_GOLDEN=1 bash scripts/test.sh full`.
6. **Pathological inputs and speed.** 20 000 nested block quotes, 400 nested
   list items, 20 000 emphasis runs in one paragraph, a 2 MB single line,
   50 000 unmatched backticks, 50 000 unmatched `[`, 20 000 unmatched `![`,
   each under two seconds; and a generated 1 MB document, about 118 ms at
   `-O2`. These are guards against an algorithm, not a benchmark — the
   unmatched-`[` case took 4.5 seconds before `MD_inlines.brackets` replaced a
   forward search per bracket with one stack pass. (The oracle takes nine
   minutes on the 1 MB file, which says more about `commonmark.py` than
   about anything here.)

Separately, and not in `test.sh` because it needs the repository's own
harness: the program builds clean under `gcc` and `clang` at `-O0` and `-O2`
with `-Wall -Wextra -Werror`, all four builds produce identical output, it is
clean under ASan and UBSan, and under `-DRC_DEBUG` every input ends with
`__rc_live=0` — no leaked object, on any test case.
