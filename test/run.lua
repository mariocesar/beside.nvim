-- Unit checks. Exit code 0 means every check passed:
--   nvim --clean --headless -c 'luafile test/run.lua'
local root =
  vim.fs.dirname(vim.fs.dirname(vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p')))
vim.opt.rtp:prepend(root)
dofile(root .. '/plugin/beside.lua')
local Beside = require('beside')
local Ansi = require('beside.ansi')
local Anchors = require('beside.anchors')

local failed = 0

local function check(name, ok, detail)
  if not ok then failed = failed + 1 end
  -- the detail explains a failure; a passing check prints its name only
  local suffix = (not ok and detail) and ('  [' .. tostring(detail) .. ']') or ''
  print((ok and 'ok   ' or 'FAIL ') .. name .. suffix)
end

local function contains(text, part) return text ~= nil and text:find(part, 1, true) ~= nil end

local function show(value)
  return vim.inspect(value, {
    newline = ' ',
    indent = '',
  })
end

-- Ansi -----------------------------------------------------------------------
print('-- ansi')

local text, spans =
  Ansi.parse('\27[1;31mred\27[0m plain \27[38;5;82mgreen\27[0m \27[38;2;1;2;3mtrue\27[m')
local expected = {
  {
    from = 0,
    to = 3,
    style = {
      bold = true,
      fg = '#800000',
    },
  },
  {
    from = 10,
    to = 15,
    style = {
      fg = '#5fff00',
    },
  },
  {
    from = 16,
    to = 20,
    style = {
      fg = '#010203',
    },
  },
}
check('escapes stripped from the text', text == 'red plain green true', text)
check('base, 256 and truecolor spans', vim.deep_equal(spans, expected), show(spans))

check('palette: xterm base colors', Ansi.palette(1) == '#800000' and Ansi.palette(15) == '#ffffff')
check('palette: cube', Ansi.palette(16) == '#000000' and Ansi.palette(231) == '#ffffff')
check('palette: grays', Ansi.palette(232) == '#080808' and Ansi.palette(255) == '#eeeeee')

vim.g.terminal_color_1 = '#123456'
check('palette: the colorscheme terminal colors win', Ansi.palette(1) == '#123456')
vim.g.terminal_color_1 = nil

-- Anchors --------------------------------------------------------------------
print('-- anchors')

local needle = Anchors.needle('- [ ] Read [the docs](http://x) now')
check('needle: markers and links stripped', needle == 'read the docs now', needle)
check('needle: nil for a short line', Anchors.needle('# a') == nil)
check('needle: cut at a word boundary', Anchors.needle('word ' .. ('x'):rep(30)) == 'word')

-- a markdown table rendered as a box: 7 source lines become 10
local source = {
  '# Title',
  '',
  'Para one',
  '| alpha | beta |',
  '|---|---|',
  '| gamma | delta |',
  'Last line here',
}
local rendered = {
  'Title',
  '',
  'Para one',
  '┌───────┬───────┐',
  '│ alpha │ beta  │',
  '├───────┼───────┤',
  '│ gamma │ delta │',
  '└───────┴───────┘',
  '',
  'Last line here',
}
local anchors = Anchors.find(source, rendered)
local first = anchors[1]
local last = anchors[#anchors]
check(
  'anchors: sentinels at both ends',
  first.source == 1 and first.preview == 1 and last.source == 7 and last.preview == 10,
  show(anchors)
)
check('anchors: first table row found', Anchors.to_preview(anchors, 4) == 5)
check('anchors: last table row found', Anchors.to_preview(anchors, 6) == 7)
check('anchors: interpolated between matches', Anchors.to_preview(anchors, 5) == 6)
check('anchors: reverse lookup of a row', Anchors.to_source(anchors, 7) == 6)
check('anchors: reverse lookup of the last line', Anchors.to_source(anchors, 10) == 7)

local identity = Anchors.find(source, source)
check('anchors: identity when nothing changed', Anchors.to_preview(identity, 5) == 5)

-- Config ---------------------------------------------------------------------
print('-- config')

local ok, err = pcall(Beside.setup, {
  width = 'wide',
})
check('a wrong type is rejected by name', not ok and contains(err, 'width'), err)

Beside.setup({
  width = 30,
})
check(
  'a setting merges over the defaults',
  Beside.config.width == 30 and Beside.config.delay == 100
)

Beside.setup({})
check('setup() resets to the defaults', Beside.config.width == 0.4)

print('-- results')
print(failed == 0 and 'all checks passed\n' or failed .. ' checks FAILED\n')
vim.cmd(failed == 0 and 'qall!' or 'cquit 1')
