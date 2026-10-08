Raw HTML is not in the subset, so a block of it is an escaped paragraph:

<div class="note">
  <p>hello</p>
</div>

<notascheme>

<not a link>

Inline raw HTML is escaped too: a <span>span</span> and a <br> break.

Entity references are not decoded: &amp; &copy; &#35; &#x2764;

A link inside a link text is not split the way CommonMark splits it: [a [b](/x)](/u)
