--- beside.nvim: a live rendering of the current document beside its buffer.

-- Module definition ==========================================================
local api = vim.api

local Beside = {}
local H = {}

--- Merge `config` over the defaults. Optional: the defaults apply without it.
---@param config table|nil See |Beside.config|.
Beside.setup = function(config)
  Beside.config = vim.tbl_deep_extend('force', vim.deepcopy(H.default_config), config or {})
end

--- Defaults
Beside.config = {
  -- Preview width: fraction of the screen, or a column count when 2 or more
  width = 0.4,
}

-- Module functionality =======================================================
--- Open the preview for the current buffer
Beside.open = function()
  local buf = api.nvim_get_current_buf()
  if not H.is_open() then H.open_window(Beside.config.width) end
  H.state.source = buf
  H.render()
end

--- Close the preview
Beside.close = function()
  -- Either may be gone already, or be the last window (E444) when the source closes
  if H.is_open() then pcall(api.nvim_win_close, H.state.win, true) end
  if H.state.buf and api.nvim_buf_is_valid(H.state.buf) then
    pcall(api.nvim_buf_delete, H.state.buf, { force = true })
  end
  H.state = {}
end

--- Close the preview when it is open, open it otherwise
Beside.toggle = function()
  if H.is_open() then return Beside.close() end
  Beside.open()
end

-- Helper data ================================================================
H.default_config = vim.deepcopy(Beside.config)

-- The preview: `win` and `buf` are the preview's, `source` the previewed buffer
H.state = {}

-- Helper functionality =======================================================
-- Preview window -------------------------------------------------------------
H.is_open = function() return H.state.win ~= nil and api.nvim_win_is_valid(H.state.win) end

-- Create the preview buffer in a split at the right, then return to the source
H.open_window = function(width)
  local source_win = api.nvim_get_current_win()
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].modifiable = false

  if width < 2 then width = math.floor(vim.o.columns * width) end
  vim.cmd.vsplit({ range = { width }, mods = { split = 'botright' } })
  local win = api.nvim_get_current_win()
  api.nvim_win_set_buf(win, buf)

  -- Plain reading: no gutter, no cursor line
  local options = {
    number = false,
    relativenumber = false,
    signcolumn = 'no',
    list = false,
    cursorline = false,
    spell = false,
  }
  for option, value in pairs(options) do
    vim.wo[win][option] = value
  end

  api.nvim_set_current_win(source_win)
  H.state.win = win
  H.state.buf = buf
end

-- Rendering ------------------------------------------------------------------
H.render = function()
  local source = H.state.source
  if not api.nvim_buf_is_valid(source) then return Beside.close() end

  local lines = api.nvim_buf_get_lines(source, 0, -1, false)
  local width = tostring(H.content_width())
  local command = { 'glow', '-s', vim.o.background, '-w', width, '-' }
  local on_exit = vim.schedule_wrap(function(result)
    if not H.is_open() then return end
    H.show(result)
  end)
  local stdin = table.concat(lines, '\n') .. '\n'
  -- glow only colors a terminal unless told otherwise
  local env = { CLICOLOR_FORCE = '1' }
  vim.system(command, { stdin = stdin, text = true, env = env }, on_exit)
end

-- Replace the preview with the render
H.show = function(result)
  local output = result.stdout or ''
  if result.code ~= 0 then
    output = ('renderer exited with code %d\n%s'):format(result.code, result.stderr or '')
  end
  -- The text alone for now; the colors are in the escapes
  output = output:gsub('\27%[[%d;]*m', '')
  local text = vim.split(output, '\n', { plain = true, trimempty = true })

  local buf = H.state.buf
  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, 0, -1, false, text)
  vim.bo[buf].modifiable = false
end

-- Columns for the render; renderers refuse very narrow ones
H.content_width = function() return math.max(20, api.nvim_win_get_width(H.state.win) - 1) end

return Beside
