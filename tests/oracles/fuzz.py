#!/usr/bin/env python3
"""Differential fuzz against the reference implementation.

    pip install commonmark
    M31_ROOT=/path/to/m31 bash build.sh
    python3 fuzz.py [seed] [cases]

Glues random lines together out of a pool of awkward fragments and compares
this program's HTML with Python `commonmark`'s, under the one normalisation
`reference.py` documents. Every fragment in the pool is inside the subset --
no raw HTML, no entity references -- so a mismatch is a bug here and not a
documented divergence. Link reference definitions ARE in the pool, with these
exceptions, each a place where the oracle itself is wrong (it contradicts the
spec) and so not usable as a judge: a title followed by more text on its line
(Python `commonmark` keeps the title it should discard), an unbalanced `(` in a
bare destination (it accepts one), and a definition followed by a setext
underline (it leaves an empty `<p></p>`, which `ref()` below removes). The
first two are in tests/references-edge.md, written by hand.

This found, among others: the rule of three reading the mutated delimiter
stack instead of the original flanking; a lazy continuation line being
re-parsed as a setext underline; `- - -` after a list item being read as
three more items.
"""
import os
import random
import subprocess
import sys
import tempfile

import commonmark

BIN = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "markdown")

FRAGS = [
    "# heading", "## heading two", "###### six", "#### with *em*",
    "para text", "para with *em* and **strong**", "para with `code`",
    "para with [link](/u) and ![img](/i)", "a <http://x.y/z> autolink",
    "line one  ", "line two\\", "trailing text",
    "---", "***", "___", "- - -",
    "> quote", ">", "> > deep",
    "- item", "- item with *em*", "  - nested", "    - deeper",
    "1. one", "2. two", "1) paren", "  1. nested ordered",
    "+ plus", "* star",
    "```", "```py", "code line", "~~~", "    indented",
    "", "", "",
    "*a", "a*", "**b", "b**", "_c", "c_", "*", "**", "***", "_", "__",
    "a*b*c", "a_b_c", "*a**b*", "**a*b**", "***a***", "a ** b",
    "`x`", "``x``", "`x", "x`", "``a ` b``",
    "[t](/u)", "[t](/u 't')", '[t](/u "t")', "[t](</u v>)", "[t](/u(v)w)",
    "[t]", "[t](", "![a](/i)", "[a [b] c](/u)",
    "\\*esc\\*", "\\\\", "\\[", "a & b < c > d \" e ' f",
    "Setext", "===", "café 中文 👍", "  indented para",
    # Link reference definitions and the three reference forms. The labels
    # `ref`, `Ref 2`, `ref3` and `ref4` are never the text of an inline-link
    # fragment above: a reference inside the text of an inline link is a
    # known divergence (README, "What is left out"), and so is `[t]` there.
    "[ref]: /r", "[ref]: /r2 \"T\"", "[Ref  2]: <http://x/y z> 'q'",
    "  [ref3]: /three", "   [ref3]: /dup (paren)", "[ref4]:", "/four",
    "\"title line\"", "'single'", "(paren title)", "[ref3]: /a\\(b\\)c?x=1&y=2",
    "[ref]", "[REF][]", "text [ref] more", "[x][ref]", "![alt][ref]", "![ref]",
    "![ref][]", "[ref 2][]", "[a *b*][Ref 2]", "[ref3]", "[ref4]", "[nope]",
    "[x][nope]", "[ref][nope]", "[ref][nope][ref3]", "[ref] [ref3]", "[ref](",
    "> [ref4]: /q", "- [ref4]: /l", "> [ref]", "- [ref3][]", "[ref]:", "[]: /e",
    "[ref]: /r *x*", "# [ref]", "[ref]\\", "\\[ref]", "[ref\\]",
    # Deliberately NO table fragments. GFM tables are an extension the oracle
    # does not implement, so a header line landing above a delimiter line is
    # a documented divergence, not a bug, and it would report as one here.
    # Tables are covered by tests/tables.md, whose expectation is hand-written.
]


def mine(text):
    fd, path = tempfile.mkstemp(suffix=".md")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        r = subprocess.run([BIN, path], capture_output=True, text=True)
        return r.stdout, r.returncode
    finally:
        os.unlink(path)


def ref(text):
    # Two more places where the oracle is brought to the spec (see the module
    # docstring): the empty `<p></p>` it leaves behind when a paragraph held
    # nothing but definitions and a setext underline followed, and the
    # percent-encoded backtick, which cmark's own href escaper leaves alone.
    return (commonmark.commonmark(text).replace("'", "&#x27;")
            .replace("<p></p>\n", "").replace("%60", "`"))


def main():
    seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    cases = int(sys.argv[2]) if len(sys.argv) > 2 else 250
    rng = random.Random(seed)
    bad = crashed = 0
    for _ in range(cases):
        text = "\n".join(rng.choice(FRAGS)
                         for _ in range(rng.randint(1, 8))) + "\n"
        got, rc = mine(text)
        if rc != 0:
            crashed += 1
            print("=== EXIT", rc, "===")
            print(repr(text))
            continue
        want = ref(text)
        if got != want:
            bad += 1
            if bad <= 20:
                print("=== MISMATCH ===")
                print("input: ", repr(text))
                print("want:  ", repr(want))
                print("got:   ", repr(got))
    print(f"seed {seed}: {cases} cases, {bad} mismatched, {crashed} crashed")
    return 1 if (bad or crashed) else 0


if __name__ == "__main__":
    raise SystemExit(main())
