# Changes

## Unreleased

Some renderers pick colors that are hard to read on my theme. pandoc's inline
code was the worst, red on light gray on a dark background. beside now fixes
those itself.

- Text under 3:1 against its background gets lightened or darkened until it
  reads. It keeps its hue, just a bit stronger.
- carve's navy links, red deletions and blue headings show up on dark themes
  without terminal colors.
- Dim text, borders and rules keep their faint colors. Faint was the point.
- Focusing a floating window no longer moves the preview to it. An LSP hover
  is a markdown buffer, so pressing `K` twice used to show the hover text in
  the preview and closing the hover closed the preview.
- R Markdown and Quarto documents preview with the markdown renderers. They
  are markdown with code chunks; the chunks show as code, nothing runs. A
  demo gif shows both.
- `:checkhealth beside` tries each installed renderer on a one-line document.
  A pandoc too old for its `ansi` writer, like the one some distros still
  package, used to pass as fine until the first preview failed; now health
  shows pandoc's own error and marks the filetypes left to it.

## v0.2.1 (2026-09-27)

carve draws table borders and quote bars dim, and highlights in reverse. The
preview ignored both, so tables looked heavy and highlights were just colored
text.

- Dim and reverse text show in the preview. Neovim has no dim, so dim text is
  blended halfway into the background.
- A contributing guide (`CONTRIBUTING.md`): how to add a renderer, record its
  demo, and the renderer quirks I keep running into.
- The README lists the renderers in a table, with install links.
- `make demo` only records the gifs that are missing.

## v0.2.0 (2026-09-27)

Carve support! [Carve](https://markup-carve.github.io/carve) documents get the
same live preview as markdown.

- `.crv` documents render beside the source with `carve --ansi`.
- `.crv` files get a `carve` filetype, since Neovim doesn't have one yet.
- A Carve demo gif, and a "why another preview" section in the README.
- The `test/sample.*` files moved to `demo/`, with a new Carve sample.

## v0.1.0 (2026-09-26)

First release! I wanted to see the rendered document next to the one I'm
writing, with whatever terminal renderer I already have, no node or browser.

- `:Beside` opens a live preview of the current document in a split. leaf,
  glow and pandoc work out of the box, so markdown, rst, asciidoc, org,
  textile, typst, djot and more.
- It re-renders as you type, no need to save.
- The preview follows the cursor, and scrolling the preview scrolls the source.
- Open another document and the preview moves to it. Close the source and the
  preview goes too, or press `q`.
- Renderers are just config. Add one as a table entry, switch with
  `:Beside glow`, order them per filetype with `prefer`.
- `vim.b.beside_config` overrides settings per buffer.
- `:checkhealth beside`, a help file and a `User BesideRender` event.
- Neovim 0.10+, nothing else to install.
