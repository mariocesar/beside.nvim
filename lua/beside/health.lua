-- :checkhealth beside
local M = {}

-- Render a one-line document with `renderer`, as the preview would. A raising
-- `command` comes back as a failed result too.
M.try = function(renderer, filetype)
  local format = renderer.filetypes[filetype]
  local context = {
    filetype = filetype,
    format = format == true and filetype or format,
    width = 60,
    background = vim.o.background,
    renderer = renderer,
  }
  local options =
    { stdin = 'Hello from beside.\n', text = true, env = renderer.env, timeout = 2000 }
  local ok, result = pcall(
    function() return vim.system(renderer.command(context), options):wait() end
  )
  if ok then return result end
  return { code = 1, stdout = '', stderr = tostring(result) }
end

M.check = function()
  local beside = require('beside')
  local renderers = beside.config.renderers
  local names = vim.tbl_keys(renderers)
  table.sort(names)

  vim.health.start('Renderers')
  local filetypes = {}
  local failing = {}
  for _, name in ipairs(names) do
    local renderer = renderers[name]
    local executable = renderer.executable or name
    local renders = vim.tbl_keys(renderer.filetypes or {})
    table.sort(renders)
    for _, filetype in ipairs(renders) do
      filetypes[filetype] = true
    end
    local list = table.concat(renders, ', ')
    if vim.fn.executable(executable) ~= 1 then
      vim.health.warn(
        ('%s: `%s` is not on $PATH; it would render %s'):format(name, executable, list)
      )
    else
      local path = vim.fn.exepath(executable)
      local result = M.try(renderer, renders[1])
      local stderr = vim.split(vim.trim(result.stderr or ''), '\n', { trimempty = true })
      if #stderr == 0 then stderr = nil end
      -- 124 is vim.system's code for a command killed at the timeout
      if result.code == 124 then
        vim.health.warn(
          ('%s (%s) did not finish rendering %s in 2 s'):format(name, path, renders[1]),
          {
            'The command must read the document from stdin and exit; is it waiting for a terminal?',
          }
        )
        failing[name] = true
      elseif result.code ~= 0 or vim.trim(result.stdout or '') == '' then
        local what = ('exited with code %d'):format(result.code)
        if result.code == 0 then what = 'printed nothing' end
        vim.health.error(('%s (%s) %s rendering %s'):format(name, path, what, renders[1]), stderr)
        failing[name] = true
      else
        vim.health.ok(('%s (%s) renders %s'):format(name, path, list))
      end
    end
  end

  vim.health.start('Filetypes')
  local list = vim.tbl_keys(filetypes)
  table.sort(list)
  for _, filetype in ipairs(list) do
    local name, _, message = beside.get_renderer(filetype)
    if name == nil then
      vim.health.warn(message)
    elseif failing[name] then
      vim.health.warn(('%s: %s, which fails above'):format(filetype, name))
    else
      vim.health.ok(('%s: %s'):format(filetype, name))
    end
  end
end

return M
