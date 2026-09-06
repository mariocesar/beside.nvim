--- A renderer is a table in `config.renderers`, keyed by its name. It runs a
--- command with the document on stdin and reads ANSI-colored text back. The
--- builtins below have the shape a user entry has; see :h beside-renderers.
---@class beside.Renderer
---@field filetypes table Filetypes it renders, each mapped to the name its
---   command needs for that format, or to `true` when that is the filetype.
---@field command function Called with a |beside.Context|, returns the argv of a
---   command that renders stdin to ANSI-colored text on stdout, no wider than
---   `context.width` columns.
---@field env table|nil Extra environment for the command.
---@field executable string|nil What must be on $PATH; the name by default.

--- What a renderer's `command` is called with
---@class beside.Context
---@field filetype string The document's filetype.
---@field format string What the renderer's `filetypes` maps it to.
---@field width integer Columns available in the preview.
---@field background string The editor's 'background', `light` or `dark`.
---@field renderer beside.Renderer The entry itself, with any user options merged in.

local renderers = {}

-- leaf renders markdown, https://github.com/RivoLink/leaf
renderers.leaf = {
  filetypes = { markdown = true },
  command = function(context)
    return { 'leaf', '--inline', 'ansi', '--width', tostring(context.width) }
  end,
}

-- glow renders markdown, https://github.com/charmbracelet/glow. Its `style`
-- option names a glow style; the editor's 'background' is the default.
renderers.glow = {
  filetypes = { markdown = true },
  env = { CLICOLOR_FORCE = '1' },
  command = function(context)
    local style = context.renderer.style or context.background
    return { 'glow', '-s', style, '-w', tostring(context.width), '-' }
  end,
}

-- pandoc 3.1.10 or newer, for its `ansi` writer. Any format pandoc reads can
-- be added to `filetypes`, mapped to pandoc's name for it.
renderers.pandoc = {
  filetypes = {
    markdown = 'gfm',
    rst = 'rst',
    asciidoc = 'asciidoc',
    org = 'org',
    textile = 'textile',
    typst = 'typst',
    djot = 'djot',
  },
  command = function(context)
    return { 'pandoc', '-f', context.format, '-t', 'ansi', '--columns', tostring(context.width) }
  end,
}

return renderers
