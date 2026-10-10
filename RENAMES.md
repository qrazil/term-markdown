# Renames and release notes

## 0.4.0 — m31 v0.4.0 (stdlib folders, naming rules)

Built and tested against m31 v0.4.0 (earlier m31 releases no longer build it).
`m31c lint` reports no findings. **No public name of markdown changed**, and
the HTML output is byte-identical: `MD_blocks`, `MD_doc`, `MD_inlines`,
`MD_refs`, `MD_render`, `MD_build`, `MD_theme`, `MD_title`, `MD_watch`, every
`pub` function, type, field and constant keep their names, so a dependent
such as tui-markdown (`import markdown.MD_doc;` and the like) changes
nothing in its own use of markdown. What it needs is m31 0.4.0 itself, and its
own imports of the moved standard-library modules (below).

What changed inside, all of it from m31 0.4.0:

| Where | Old | New |
|---|---|---|
| `MD_inlines`, `MD_render`, `MD_theme` | `import html;` | `import encoding.html;` |
| `MD_inlines` | `import unicode;` | `import text.unicode;` |
| `MD_watch` | `fs.exists(..)` | `fs.is_present(..)` |
| `main` | `os.args()` | `os.arguments()` |
| `main` | `options.flag("..")` (reading a parsed flag) | `options.is_flag_set("..")` |

The modules are still called by their last segment (`html.escape`,
`unicode.fold`). `parser.flag(..)` (declaring a flag on `args.Parser`) is
unchanged.

Version 0.4.0 (was 0.3.1); CI pins `M31_REF: v0.4.0`.

---

# 0.2.0 — the m31 naming convention

Old name -> new name, per `docs/naming-decision.md` of the m31 repository
(modules take a `PREFIX_`; a `bool` answers a question and starts with `is_`,
`has_`, `can_` and the like). This list is exhaustive for the 48 findings of
`m31c lint`; nothing here changes behaviour, and the HTML output is
byte-identical.

## Modules (breaking for anything that imports them)

| Old | New |
|---|---|
| `blocks` (`blocks.m31`) | `MD_blocks` (`MD_blocks.m31`) |
| `doc` (`doc.m31`) | `MD_doc` (`MD_doc.m31`) |
| `inlines` (`inlines.m31`) | `MD_inlines` (`MD_inlines.m31`) |
| `render` (`render.m31`) | `MD_render` (`MD_render.m31`) |

`main.m31` is the program's entry point and keeps its name.

## Public names (`pub`)

| Where | Old | New |
|---|---|---|
| `MD_doc.Listing` field | `ordered` | `is_ordered` |
| `MD_doc.Listing` field | `tight` | `is_tight` |

Every other `pub` name (`MD_blocks.parse`, `MD_inlines.render`,
`MD_render.document`, the `Block` variants, the `ALIGN_*` constants and the
other `MD_doc` types and fields) is unchanged.

## Private names

### `MD_blocks`

| Old | New | Kind |
|---|---|---|
| `blank` | `is_blank` | function |
| `thematic` | `is_thematic_break` | function |
| `starts_block` | `is_block_start` | function |
| `interrupts` | `can_interrupt_paragraph` | function |
| `Marker.found` | `Marker.is_found` | field |
| `Marker.ordered` | `Marker.is_ordered` | field |
| `any` (in `expand_tabs`) | `has_tab` | local |
| `closed` | `is_closed` | local |
| `done` | `is_done` | local (four functions) |
| `loose` | `is_loose` | local |
| `pending` | `has_pending_blank` | local |
| `ended` | `is_ended` | local |
| `lazy` | `is_lazy` | local |
| `lead` | `has_leading_colon` | local |
| `tail` | `has_trailing_colon` | local |

### `MD_inlines`

| Old | New | Kind |
|---|---|---|
| `space_byte` | `is_space_byte` | function |
| `punctuation_byte` | `is_punctuation_byte` | function |
| `alphabetic_byte` | `is_alphabetic_byte` | function |
| `digit_byte` | `is_digit_byte` | function |
| `alphanumeric_byte` | `is_alphanumeric_byte` | function |
| `href_safe` | `is_href_safe` | function |
| `labels_ok` | `has_valid_labels` | function |
| `Node.delimiter` | `Node.is_delimiter` | field |
| `Node.opener` | `Node.can_open` | field |
| `Node.closer` | `Node.can_close` | field |
| `Node.dead` | `Node.is_dead` | field |
| `Target.valid` | `Target.is_valid` | field |
| `opens`, `closes` (`delimiter_node`) | `can_open`, `can_close` | parameters |
| `before_space` | `is_space_before` | local |
| `before_punctuation` | `is_punctuation_before` | local |
| `after_space` | `is_space_after` | local |
| `after_punctuation` | `is_punctuation_after` | local |
| `left` | `is_left_flanking` | local |
| `right` | `is_right_flanking` | local |
| `odd` | `is_odd_match` | local |

### `MD_render`

| Old | New | Kind |
|---|---|---|
| `Out.at_line_start` | `Out.is_at_line_start` | field |
| `tight` (`blocks`, `block`) | `is_tight` | parameter |
