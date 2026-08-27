# beside.nvim

A live rendering of the document you are editing, in a split beside it,
done by a terminal renderer you already have.

## Requirements

- Neovim 0.10 or newer
- [glow](https://github.com/charmbracelet/glow) on `$PATH`

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ 'mariocesar/beside.nvim', cmd = 'Beside', opts = {} }
```

## Use

`:Beside` opens the preview for the current buffer, `:Beside` again closes it.
While the preview is open:

- moving or scrolling in the source keeps the preview at the same place, and
  scrolling the preview scrolls the source
- edits re-render 100 ms after you stop typing, unsaved
- opening another document in the same tab moves the preview to it; when no
  window shows the document any more, the preview closes
- `q` in the preview closes it

## Configuration

The defaults:

```lua
require('beside').setup({
  -- Preview width: fraction of the screen, or a column count when 2 or more
  width = 0.4,

  -- Milliseconds after the last change before re-rendering
  delay = 100,
})
```

## How the sync works

Renderers change the line count: a table becomes a box, a paragraph wraps, a
code block grows a frame. There is no line-for-line map, so beside matches the
text of each source line to the rendered output and interpolates between
matches. Headings, list items, code lines and table cells anchor exactly;
inside a wrapped paragraph the preview lands within a line or two.

## Development

```sh
make test          # nvim --clean --headless -c 'luafile test/run.lua'
```

Tests print one line per check and need no renderer installed.

## License

MIT
