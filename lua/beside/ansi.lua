-- ANSI SGR escapes to plain text and styles. Renderers print these; the preview
-- shows the text and highlights the styled spans.
local Ansi = {}

-- xterm's 16 base colors, for a colorscheme that does not set terminal colors
local xterm = {
  '#000000',
  '#800000',
  '#008000',
  '#808000',
  '#000080',
  '#800080',
  '#008080',
  '#c0c0c0',
  '#808080',
  '#ff0000',
  '#00ff00',
  '#ffff00',
  '#0000ff',
  '#ff00ff',
  '#00ffff',
  '#ffffff',
}

-- Attributes a single SGR code turns on, and the codes turning them off
local attributes = {
  [1] = 'bold',
  [2] = 'dim',
  [3] = 'italic',
  [4] = 'underline',
  [7] = 'reverse',
  [9] = 'strikethrough',
}
local resets = {
  [22] = { 'bold', 'dim' },
  [23] = { 'italic' },
  [24] = { 'underline' },
  [27] = { 'reverse' },
  [29] = { 'strikethrough' },
  [39] = { 'fg' },
  [49] = { 'bg' },
}

--- '#rrggbb' for a 256-color index: the colorscheme's terminal colors for the
--- first 16 when it sets them, xterm's values otherwise
---@param index integer 0 to 255
---@return string
Ansi.palette = function(index)
  if index < 16 then return vim.g['terminal_color_' .. index] or xterm[index + 1] end
  if index >= 232 then
    local gray = 8 + (index - 232) * 10
    return ('#%02x%02x%02x'):format(gray, gray, gray)
  end
  local cube = index - 16
  local level = function(value) return value == 0 and 0 or 55 + value * 40 end
  local red = level(math.floor(cube / 36))
  local green = level(math.floor(cube / 6) % 6)
  local blue = level(cube % 6)
  return ('#%02x%02x%02x'):format(red, green, blue)
end

--- Mix two '#rrggbb' colors, `amount` 0 gives `from`, 1 gives `to`
---@param from string
---@param to string
---@param amount number
---@return string
Ansi.blend = function(from, to, amount)
  local a = tonumber(from:sub(2), 16)
  local b = tonumber(to:sub(2), 16)
  local channels = {}
  for _, shift in ipairs({ 16, 8, 0 }) do
    local x = math.floor(a / 2 ^ shift) % 256
    local y = math.floor(b / 2 ^ shift) % 256
    channels[#channels + 1] = math.floor(x + (y - x) * amount + 0.5)
  end
  return ('#%02x%02x%02x'):format(channels[1], channels[2], channels[3])
end

--- WCAG contrast ratio of two '#rrggbb' colors, from 1 to 21
---@param a string
---@param b string
---@return number
Ansi.contrast = function(a, b)
  local luminance = function(color)
    local n = tonumber(color:sub(2), 16)
    local total = 0
    for i, weight in ipairs({ 0.2126, 0.7152, 0.0722 }) do
      local channel = (math.floor(n / 2 ^ (24 - 8 * i)) % 256) / 255
      if channel <= 0.03928 then
        channel = channel / 12.92
      else
        channel = ((channel + 0.055) / 1.055) ^ 2.4
      end
      total = total + weight * channel
    end
    return total
  end
  local light = math.max(luminance(a), luminance(b))
  local dark = math.min(luminance(a), luminance(b))
  return (light + 0.05) / (dark + 0.05)
end

--- `fg` when it reads at 3:1 on `bg`, otherwise `fg` moved toward white or
--- black, whichever is further from `bg`, until it does
---@param fg string
---@param bg string
---@return string
Ansi.readable = function(fg, bg)
  if Ansi.contrast(fg, bg) >= 3 then return fg end
  local target = '#000000'
  if Ansi.contrast('#ffffff', bg) > Ansi.contrast('#000000', bg) then target = '#ffffff' end
  for step = 1, 10 do
    local color = Ansi.blend(fg, target, step / 10)
    if Ansi.contrast(color, bg) >= 3 then return color end
  end
  return target
end

-- The color following a 38 or 48 code: `5;n` from the palette, `2;r;g;b` as is
Ansi.extended_color = function(codes)
  local mode = table.remove(codes, 1)
  if mode == '5' then return Ansi.palette(tonumber(table.remove(codes, 1)) or 0) end
  if mode == '2' then
    local red = tonumber(table.remove(codes, 1)) or 0
    local green = tonumber(table.remove(codes, 1)) or 0
    local blue = tonumber(table.remove(codes, 1)) or 0
    return ('#%02x%02x%02x'):format(red, green, blue)
  end
  return nil
end

-- Apply the parameters of one SGR sequence to `style`, returning the new style
Ansi.apply = function(style, codes)
  while #codes > 0 do
    local code = tonumber(table.remove(codes, 1)) or 0
    if code == 0 then
      style = {}
    elseif attributes[code] then
      style[attributes[code]] = true
    elseif resets[code] then
      for _, attribute in ipairs(resets[code]) do
        style[attribute] = nil
      end
    elseif code >= 30 and code <= 37 then
      style.fg = Ansi.palette(code - 30)
    elseif code >= 90 and code <= 97 then
      style.fg = Ansi.palette(code - 82)
    elseif code >= 40 and code <= 47 then
      style.bg = Ansi.palette(code - 40)
    elseif code >= 100 and code <= 107 then
      style.bg = Ansi.palette(code - 92)
    elseif code == 38 or code == 48 then
      style[code == 38 and 'fg' or 'bg'] = Ansi.extended_color(codes)
    end
  end
  return style
end

--- Split an SGR-colored line into plain text and styled spans
---@param line string
---@return string text The line without escapes.
---@return table spans Array of `{ from = byte, to = byte, style = table }`, `from`
---   0-based and `to` exclusive. A style has any of `fg`, `bg` ('#rrggbb') and
---   `bold`, `dim`, `italic`, `underline`, `reverse`, `strikethrough` (true).
Ansi.parse = function(line)
  -- OSC sequences carry hyperlinks and show nothing
  line = line:gsub('\27%][^\7\27]*\7', ''):gsub('\27%][^\7\27]*\27\\', '')
  local text = {}
  local spans = {}
  local style = {}
  local col = 0
  local pos = 1
  while true do
    local start, stop, params = line:find('\27%[([%d;]*)m', pos)
    local chunk = line:sub(pos, start and start - 1 or -1)
    if #chunk > 0 then
      text[#text + 1] = chunk
      if next(style) then
        spans[#spans + 1] = { from = col, to = col + #chunk, style = vim.deepcopy(style) }
      end
      col = col + #chunk
    end
    if start == nil then break end
    style = Ansi.apply(style, vim.split(params, ';', { plain = true }))
    pos = stop + 1
  end
  return table.concat(text), spans
end

return Ansi
