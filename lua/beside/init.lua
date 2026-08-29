--- beside.nvim: a live rendering of the current document beside its buffer.

-- Module definition ==========================================================
local Ansi = require('beside.ansi')
local Anchors = require('beside.anchors')
local api = vim.api

local Beside = {}
local H = {}

--- Merge `config` over the defaults, checking types. Optional: the defaults
--- apply without it.
---@param config table|nil See |Beside.config|.
Beside.setup = function(config)
  config = H.setup_config(config)
  H.apply_config(config)
end

--- Defaults. User settings deep-merge into them. The README repeats this
--- table, keep it in step.
Beside.config = {
  -- Preview width: fraction of the screen, or a column count when 2 or more
  width = 0.4,

  -- Milliseconds after the last change before re-rendering
  delay = 100,
}

-- Module functionality =======================================================
--- Open the preview for the current buffer, or move it here when it is open
--- for another one.
Beside.open = function()
  local buf = api.nvim_get_current_buf()
  local config = H.get_config(buf)
  if not H.is_open() then H.open_window(config.width) end
  H.attach(buf)
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

--- Close the preview when the current buffer is the previewed one or the
--- preview itself, open it otherwise.
Beside.toggle = function()
  local buf = api.nvim_get_current_buf()
  local is_preview = H.is_open() and buf == H.state.buf
  local is_source = H.is_open() and buf == H.state.source
  if is_preview or is_source then return Beside.close() end
  Beside.open()
end

-- Helper data ================================================================
H.default_config = vim.deepcopy(Beside.config)

H.ns = api.nvim_create_namespace('beside')
H.augroup = api.nvim_create_augroup('beside', {})
H.timer = vim.uv.new_timer()

-- The preview: `win` and `buf` are the preview's, `source` the previewed
-- buffer, `anchors` where its lines were found in the render. `run` counts
-- renders so a superseded one is dropped; it is the only field that survives
-- a close.
H.state = { run = 0, anchors = {} }

-- Helper functionality =======================================================
-- Settings -------------------------------------------------------------------
H.setup_config = function(config)
  H.check_type('config', config, 'table', true)
  config = vim.tbl_deep_extend('force', vim.deepcopy(H.default_config), config or {})

  H.check_type('width', config.width, 'number')
  H.check_type('delay', config.delay, 'number')

  return config
end

H.apply_config = function(config) Beside.config = config end

-- The config for a buffer: its `vim.b.beside_config` over the global one
H.get_config = function(buf)
  local local_config = vim.b[buf].beside_config or {}
  return vim.tbl_deep_extend('force', Beside.config, local_config)
end

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

  -- Plain reading: no gutter, no cursor line. 'scrolloff' 0 so the topline sync sets holds.
  local options = {
    number = false,
    relativenumber = false,
    signcolumn = 'no',
    list = false,
    cursorline = false,
    scrolloff = 0,
    spell = false,
  }
  for option, value in pairs(options) do
    vim.wo[win][option] = value
  end
  vim.keymap.set('n', 'q', Beside.close, { buffer = buf, desc = 'Close the preview' })

  api.nvim_set_current_win(source_win)
  H.state.win = win
  H.state.buf = buf
end

-- Preview `buf`: sync both ways, render on change, close with it
H.attach = function(buf)
  H.state.source = buf
  H.state.anchors = {}
  H.state.source_view = nil
  H.state.preview_top = nil

  local name = vim.fn.fnamemodify(api.nvim_buf_get_name(buf), ':t')
  api.nvim_buf_set_name(H.state.buf, 'beside://' .. name)
  H.create_autocommands(buf)
  H.render()
end

H.create_autocommands = function(buf)
  api.nvim_clear_autocmds({ group = H.augroup })
  local au = function(event, opts, callback, desc)
    opts = vim.tbl_extend('force', { group = H.augroup, callback = callback, desc = desc }, opts)
    api.nvim_create_autocmd(event, opts)
  end

  au({ 'CursorMoved', 'CursorMovedI' }, { buffer = buf }, H.sync_preview, 'Follow the cursor')
  au(
    { 'TextChanged', 'TextChangedI', 'TextChangedP' },
    { buffer = buf },
    H.schedule_render,
    'Re-render'
  )
  au('WinScrolled', {}, H.on_scroll, 'Sync a scroll on either side')
  au({ 'WinResized', 'VimResized' }, {}, H.on_resize, 'Re-render at the new width')
  au('ColorScheme', {}, H.render, 'Re-render with the new colors')
  au('BufEnter', {}, H.on_buf_enter, 'Move along to a document opened beside')
  au('BufWinLeave', { buffer = buf }, H.on_source_hidden, 'Close when the source is gone')
  au('QuitPre', { buffer = buf }, Beside.close, 'Close with the source')
  au('WinClosed', { pattern = tostring(H.state.win) }, H.on_preview_closed, 'Clean up after :q')
end

H.reset_state = function() H.state = { run = H.state.run, anchors = {} } end

H.on_scroll = function()
  local preview_scrolled = vim.v.event[tostring(H.state.win)] ~= nil
  if preview_scrolled then
    -- Only a scroll made in the preview, not the one sync_preview() set
    local top = api.nvim_win_call(H.state.win, vim.fn.winsaveview).topline
    if top ~= H.state.preview_top then H.follow_source() end
  elseif vim.v.event[tostring(api.nvim_get_current_win())] then
    H.sync_preview()
  end
end

H.on_resize = function()
  if H.can_sync() and H.content_width() ~= H.state.width then H.render() end
end

-- The preview moves along to a markdown document opened beside it
H.on_buf_enter = function(event)
  local buf = event.buf
  if not H.is_open() or buf == H.state.source or buf == H.state.buf then return end
  if api.nvim_win_get_tabpage(0) ~= api.nvim_win_get_tabpage(H.state.win) then return end
  if vim.bo[buf].filetype == 'markdown' then H.attach(buf) end
end

-- Checked after the event, since BufEnter may have moved the preview along
H.on_source_hidden = function()
  vim.schedule(function()
    if H.is_open() and #vim.fn.win_findbuf(H.state.source) == 0 then Beside.close() end
  end)
end

-- The window is going away on its own
H.on_preview_closed = function()
  H.state.win = nil
  Beside.close()
end

-- Rendering ------------------------------------------------------------------
H.render = function()
  local source = H.state.source
  if not api.nvim_buf_is_valid(source) then return Beside.close() end

  local lines = api.nvim_buf_get_lines(source, 0, -1, false)
  H.state.changedtick = vim.b[source].changedtick
  H.state.width = H.content_width()
  local command = { 'glow', '-s', vim.o.background, '-w', tostring(H.state.width), '-' }

  -- Any render still running is superseded: its result is dropped
  H.state.run = H.state.run + 1
  local run = H.state.run
  local on_exit = vim.schedule_wrap(function(result)
    if run ~= H.state.run or not H.is_open() then return end
    H.show(lines, result)
  end)
  local stdin = table.concat(lines, '\n') .. '\n'
  -- glow only colors a terminal unless told otherwise
  local env = { CLICOLOR_FORCE = '1' }
  vim.system(command, { stdin = stdin, text = true, env = env }, on_exit)
end

-- Render shortly after the last change; glow takes ~20 ms, so it feels live
H.schedule_render = function()
  H.timer:stop()
  H.timer:start(H.get_config(H.state.source).delay, 0, vim.schedule_wrap(H.render_if_changed))
end

H.render_if_changed = function()
  local source = H.state.source
  if source == nil or not api.nvim_buf_is_valid(source) then return end
  if vim.b[source].changedtick ~= H.state.changedtick then H.render() end
end

-- Replace the preview with the render of these source lines
H.show = function(source_lines, result)
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

  H.state.anchors = Anchors.find(source_lines, text)
  H.sync_preview(true)
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

-- Sync -----------------------------------------------------------------------
H.can_sync = function()
  return H.is_open() and api.nvim_buf_is_valid(H.state.source) and #H.state.anchors > 0
end

-- Scroll the preview so the cursor's line sits at the cursor's screen row.
-- Each side records the view it set on the other (`preview_top`, `source_view`)
-- so the WinScrolled it causes there is not synced straight back.
H.sync_preview = function(force)
  if not H.can_sync() or api.nvim_get_current_buf() ~= H.state.source then return end
  if force ~= true and H.view_key(0) == H.state.source_view then return end
  H.state.source_view = nil

  local line = api.nvim_win_get_cursor(0)[1]
  local target = Anchors.to_preview(H.state.anchors, line)
  target = math.max(1, math.min(target, api.nvim_buf_line_count(H.state.buf)))
  local row = vim.fn.winline()
  api.nvim_win_call(H.state.win, function()
    vim.fn.winrestview({ lnum = target, col = 0, topline = math.max(1, target - row + 1) })
    H.state.preview_top = vim.fn.winsaveview().topline
  end)
end

-- Scroll the source so the line at the preview's top sits at the source's top
H.follow_source = function()
  local source_win = vim.fn.bufwinid(H.state.source)
  if not H.can_sync() or source_win == -1 then return end

  local top = api.nvim_win_call(H.state.win, vim.fn.winsaveview).topline
  local target = Anchors.to_source(H.state.anchors, top)
  target = math.max(1, math.min(target, api.nvim_buf_line_count(H.state.source)))
  api.nvim_win_call(source_win, function()
    -- <C-e>/<C-y> drag the cursor along; setting topline alone would not
    local delta = target - vim.fn.winsaveview().topline
    if delta > 0 then vim.cmd('normal! ' .. delta .. vim.keycode('<C-e>')) end
    if delta < 0 then vim.cmd('normal! ' .. -delta .. vim.keycode('<C-y>')) end
    H.state.source_view = H.view_key(0)
  end)
  H.state.preview_top = top
end

H.view_key = function(win)
  local view = api.nvim_win_call(win, vim.fn.winsaveview)
  return view.topline .. ':' .. view.lnum
end

-- Utilities ------------------------------------------------------------------
H.error = function(msg) error('(beside) ' .. msg, 0) end

H.check_type = function(name, val, ref, allow_nil)
  if type(val) == ref or (allow_nil and val == nil) then return end
  H.error(('`%s` should be %s, not %s'):format(name, ref, type(val)))
end

return Beside
