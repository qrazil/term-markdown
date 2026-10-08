# Where definitions live

A definition may not interrupt a paragraph, so this is text and so is
[not-a-def]:
a paragraph
[late]: /url
[late]

It begins a paragraph, though, and the rest stays one:

[one]: /1
[two]: /2
the paragraph that is left, with [one] and [two]

[only]: /only

> [quoted]: /in-a-quote
> A quote, using [quoted] and [list-item] and [top].

- [list-item]: /in-a-list
- an item using [list-item], [quoted] and [top]

  - [nested]: /nested
  - and [nested] again

1. [ordered]: /ordered
   and [ordered] on the line after it

Heading [top]
=============

[top]: /top

## [top] in a heading

A definition does not apply to a block of code:

    [top]: /not-a-def

```
[top]: /nor-this
```

    [fenced-above]: /not-this-either

[fenced-above] is not defined.

Four spaces make code, three do not:

   [three]: /3
[three]
