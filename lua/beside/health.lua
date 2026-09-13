-- :checkhealth beside
local M = {}

M.check = function()
  local beside = require('beside')
  local renderers = beside.config.renderers
  local names = vim.tbl_keys(renderers)
  table.sort(names)

  vim.health.start('Renderers')
  local filetypes = {}
  for _, name in ipairs(names) do
    local renderer = renderers[name]
    local executable = renderer.executable or name
    local renders = vim.tbl_keys(renderer.filetypes or {})
    table.sort(renders)
    for _, filetype in ipairs(renders) do
      filetypes[filetype] = true
    end
    local list = table.concat(renders, ', ')
    if vim.fn.executable(executable) == 1 then
      vim.health.ok(('%s (%s) renders %s'):format(name, vim.fn.exepath(executable), list))
    else
      vim.health.warn(
        ('%s: `%s` is not on $PATH; it would render %s'):format(name, executable, list)
      )
    end
  end

  vim.health.start('Filetypes')
  local list = vim.tbl_keys(filetypes)
  table.sort(list)
  for _, filetype in ipairs(list) do
    local name, _, message = beside.get_renderer(filetype)
    if name then
      vim.health.ok(('%s: %s'):format(filetype, name))
    else
      vim.health.warn(message)
    end
  end
end

return M
