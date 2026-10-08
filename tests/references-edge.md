A definition whose title is followed by text has no title, and the "title" starts a paragraph:

[one]: /one "not a title" trailing

[one]

A title on the next line, then text after it, is not part of the definition:

[two]: /two
"title" and more

[two]

An unbalanced parenthesis in a bare destination: no definition, and [three] stays literal

[three]: /a(b

[three]

A definition then a thematic break:

[four]: /four
---

[four]

A definition then an equals line is a paragraph: [five]

[five]: /five
===

[five]

An empty label is no definition, nor is a label of blanks:

[]: /empty

[ ]: /blank

[x]: <>

[x]

Pointy destinations may hold spaces and are not trimmed: [six]

[six]: </a b> 'single'

[six]

A reference inside a table cell:

| a | b |
|---|---|
| [six] | [seven] |

[seven]: /seven

A label with a backslash-escaped bracket: [a\]b]

[a\]b]: /escaped

A label with a bracket in it that is not escaped is no definition:

[a]b]: /nope

[a]b]

Unicode case folding: [STRASSE] and [Straße]

[straße]: /ss

Many labels, one paragraph: [m] [n]

[m]: /m
[n]: /n
[o]: /o

[m] [o]
