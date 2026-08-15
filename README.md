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

## License

MIT
