# Reference links

A full reference, [the text][foo], a collapsed one, [foo][], and a shortcut,
[foo]. The label ignores case and runs of white space: [FOO], [Foo][fOO],
[a   b] and [A B][]. Whitespace inside the label counts as one space, even
across a line break: [a
b].

Images: ![the alt][foo], ![foo][], ![foo] and ![an *emphasised* alt][a b].

The text may hold markup: [*em* and `code`][foo], and a reference link may
sit inside emphasis: *[foo]* and **[foo][]**.

A definition can come after the use; so can all of them. Unmatched
references stay literal text: [nope], [nope][], [text][nope], [foo][nope],
![nope] and ![alt][nope]. A label is not a fallback: [foo][nope] above is
literal even though `foo` exists. Brackets inside a shortcut label are not
allowed, so [foo [bar]] is not one, while [[foo]] is a link in brackets.

An inline destination wins over a reference: [foo](/inline) and
[foo]( not an inline link ). The reference is used when the parentheses do
not make a link: [foo](bad "title).

Escapes: \[foo] is literal, [foo\] is not closed, and `[foo]` in a code span
is code. A link text is not a label: [`foo`] and [foo`]`] are not links.

[foo]: /url "the title"
[a b]: <my url> 'single "quoted" title'
[Dup]: /first
[dup]: /second
[ESC]: /a\(b\)c?x=1&y=2 "title with \"escapes\" and & < >"
[paren]: /p (parenthesised)
   [indented]: /three-spaces
[next line]:
   /on-the-next-line
   "and its title, on the line after"
[line break
in label]: /multi
[empty]: <>
[unicode]: /café/中文 "ü"

First definition wins: [dup], [Dup] and [DUP][]. Others: [ESC], [paren],
[indented], [next line], [line break in label], [empty], [unicode].
