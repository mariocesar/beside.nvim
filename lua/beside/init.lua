--- beside.nvim: a live rendering of the current document beside its buffer.

-- Module definition ==========================================================
local Ansi = require('beside.ansi')
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

  -- Milliseconds after the last change before re-rendering
  delay = 100,
}

-- Module functionality =======================================================
--- Open the preview for the current buffer
Beside.open = function()
  local buf = api.nvim_get_current_buf()
  if not H.is_open() then H.open_window(Beside.config.width) end
  H.state.source = buf
  H.create_autocommands(buf)
  H.render()
end

--- Close the preview
Beside.close = function()
  api.nvim_clear_autocmds({ group = H.augroup })
  H.timer:stop()
  -- Either may be gone already, or be the last window (E444) when the source closes
  if H.is_open() then pcall(api.nvim_win_close, H.state.win, true) end
  if H.state.buf and api.nvim_buf_is_valid(H.state.buf) then
    pcall(api.nvim_buf_delete, H.state.buf, { force = true })
  end
  H.reset_state()
end

--- Close the preview when it is open, open it otherwise
Beside.toggle = function()
  if H.is_open() then return Beside.close() end
  Beside.open()
end

-- Helper data ================================================================
H.default_config = vim.deepcopy(Beside.config)

H.ns = api.nvim_create_namespace('beside')
H.augroup = api.nvim_create_augroup('beside', {})
H.timer = vim.uv.new_timer()

-- The preview: `win` and `buf` are the preview's, `source` the previewed
-- buffer. `run` counts renders so a superseded one is dropped; it is the only
-- field that survives a close.
H.state = { run = 0 }

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

H.create_autocommands = function(buf)
  api.nvim_clear_autocmds({ group = H.augroup })
  local au = function(event, opts, callback, desc)
    opts = vim.tbl_extend('force', { group = H.augroup, callback = callback, desc = desc }, opts)
    api.nvim_create_autocmd(event, opts)
  end

  au(
    { 'TextChanged', 'TextChangedI', 'TextChangedP' },
    { buffer = buf },
    H.schedule_render,
    'Re-render'
  )
  au('ColorScheme', {}, H.render, 'Re-render with the new colors')
end

H.reset_state = function() H.state = { run = H.state.run } end

-- Rendering ------------------------------------------------------------------
H.render = function()
  local source = H.state.source
  if not api.nvim_buf_is_valid(source) then return Beside.close() end

  local lines = api.nvim_buf_get_lines(source, 0, -1, false)
  H.state.changedtick = vim.b[source].changedtick
  local width = tostring(H.content_width())
  local command = { 'glow', '-s', vim.o.background, '-w', width, '-' }

  -- Any render still running is superseded: its result is dropped
  H.state.run = H.state.run + 1
  local run = H.state.run
  local on_exit = vim.schedule_wrap(function(result)
    if run ~= H.state.run or not H.is_open() then return end
    H.show(result)
  end)
  local stdin = table.concat(lines, '\n') .. '\n'
  -- glow only colors a terminal unless told otherwise
  local env = { CLICOLOR_FORCE = '1' }
  vim.system(command, { stdin = stdin, text = true, env = env }, on_exit)
end

-- Render shortly after the last change; glow takes ~20 ms, so it feels live
H.schedule_render = function()
  H.timer:stop()
  H.timer:start(Beside.config.delay, 0, vim.schedule_wrap(H.render_if_changed))
end

H.render_if_changed = function()
  local source = H.state.source
  if source == nil or not api.nvim_buf_is_valid(source) then return end
  if vim.b[source].changedtick ~= H.state.changedtick then H.render() end
end

-- Replace the preview with the render
H.show = function(result)
  local output = result.stdout or ''
  if result.code ~= 0 then
    output = ('renderer exited with code %d\n%s'):format(result.code, result.stderr or '')
  end
  local text = {}
  local spans = {}
  for i, line in ipairs(vim.split(output, '\n', { plain = true, trimempty = true })) do
    text[i], spans[i] = Ansi.parse(line)
  end

  local buf = H.state.buf
  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, 0, -1, false, text)
  vim.bo[buf].modifiable = false
  H.set_highlights(buf, spans)
end

H.set_highlights = function(buf, spans)
  api.nvim_buf_clear_namespace(buf, H.ns, 0, -1)
  for row, line_spans in ipairs(spans) do
    for _, span in ipairs(line_spans) do
      local group = H.highlight_group(span.style)
      api.nvim_buf_set_extmark(
        buf,
        H.ns,
        row - 1,
        span.from,
        { end_col = span.to, hl_group = group }
      )
    end
  end
end

-- A highlight group for an ANSI style, named after its contents so equal
-- styles share one. Defined again whenever a colorscheme change has cleared it.
H.highlight_group = function(style)
  local fg = (style.fg or ''):gsub('#', '')
  local bg = (style.bg or ''):gsub('#', '')
  local name = 'Beside_' .. fg .. '_' .. bg
  for _, attribute in ipairs({ 'bold', 'italic', 'underline', 'strikethrough' }) do
    if style[attribute] then name = name .. '_' .. attribute:sub(1, 1) end
  end
  if vim.tbl_isempty(api.nvim_get_hl(0, { name = name })) then api.nvim_set_hl(0, name, style) end
  return name
end

-- Columns for the render; renderers refuse very narrow ones
H.content_width = function() return math.max(20, api.nvim_win_get_width(H.state.win) - 1) end

return Beside
