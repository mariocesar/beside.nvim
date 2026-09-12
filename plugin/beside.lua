vim.api.nvim_create_user_command(
  'Beside',
  function(command) require('beside').toggle({ renderer = command.fargs[1] }) end,
  {
    nargs = '?',
    complete = function()
      local names = vim.tbl_keys(require('beside').config.renderers)
      table.sort(names)
      return names
    end,
    desc = 'Toggle a live rendering of the current document beside it; a name picks the renderer',
  }
)
