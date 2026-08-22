-- Matching source lines to rendered lines. Renderers change the line count, so
-- each source line's text is searched for in the render and positions between
-- the matches are interpolated.
local Anchors = {}

-- Line text with markup, box drawing and punctuation stripped
Anchors.plain = function(line)
  -- U+2000 to U+27FF: bullets, box drawing, checkboxes
  line = line:gsub('\226[\128-\159][\128-\191]', ' ')
  line = line:gsub('%p', ' '):lower()
  line = line:gsub('%s+', ' ')
  return vim.trim(line)
end

-- What to search for in the render: the start of a source line's text, or nil
-- when the line is too short to be telling
Anchors.needle = function(line)
  line = line:gsub('^%s*[-*+]%s+%[[ xX]%]', '') -- task list marker
  line = line:gsub('!?%[([^%]]*)%]%([^%)]*%)', '%1') -- links and images keep their text
  local needle = Anchors.plain(line)
  if #needle < 4 then return nil end
  -- Short enough to sit inside the first wrapped line of a paragraph in a narrow split
  if #needle > 24 then needle = needle:sub(1, 24):gsub(' %S*$', '', 1) end
  return needle
end

--- Where source lines were found in the render
---@param source string[] Source lines.
---@param rendered string[] Rendered lines, escapes stripped.
---@return table Array of `{ source = line, preview = line }` in order. The first
---   and last are sentinels pairing the two starts and the two ends, so a lookup
---   can interpolate before the first match and after the last.
Anchors.find = function(source, rendered)
  local plain = vim.tbl_map(Anchors.plain, rendered)
  local anchors = { { source = 1, preview = 1 } }
  local last_source = 1
  local last_preview = 0
  for i, line in ipairs(source) do
    local needle = Anchors.needle(line)
    if needle then
      -- A block renders in at most ~3x its source lines (tables, code frames), plus slack
      local limit = math.min(#rendered, last_preview + (i - last_source) * 3 + 12)
      for r = last_preview + 1, limit do
        if plain[r]:find(needle, 1, true) then
          anchors[#anchors + 1] = { source = i, preview = r }
          last_source = i
          last_preview = r
          break
        end
      end
    end
  end
  anchors[#anchors + 1] = { source = #source, preview = #rendered }
  return anchors
end

-- The line on side `to` for `line` on side `from`, interpolated between the
-- anchors around it
Anchors.interpolate = function(anchors, line, from, to)
  for n = 2, #anchors do
    local low = anchors[n - 1]
    local high = anchors[n]
    if line <= high[from] then
      if high[from] == low[from] then return high[to] end
      local ratio = (line - low[from]) / (high[from] - low[from])
      return math.floor(low[to] + ratio * (high[to] - low[to]) + 0.5)
    end
  end
  return anchors[#anchors][to]
end

--- Preview line for a source line
Anchors.to_preview = function(anchors, source_line)
  return Anchors.interpolate(anchors, source_line, 'source', 'preview')
end

--- Source line for a preview line
Anchors.to_source = function(anchors, preview_line)
  return Anchors.interpolate(anchors, preview_line, 'preview', 'source')
end

return Anchors
