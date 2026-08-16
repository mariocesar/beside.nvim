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
Edits re-render 100 ms after you stop typing, unsaved.

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

## License

MIT
