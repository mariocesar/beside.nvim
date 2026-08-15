vim.api.nvim_create_user_command(
  'Beside',
  function() require('beside').toggle() end,
  { desc = 'Toggle a live rendering of the current document beside it' }
)
