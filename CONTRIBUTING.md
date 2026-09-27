# Contributing

Thanks for taking a look. Bug reports, fixes and new renderers are all
welcome. If you're not sure something fits, open an issue first and we can
talk it through before you write code.

One thing to know up front: beside previews documents, and stays small on
purpose. Report generators, diff-based updates and a render cache are left out
by choice, not by oversight.

## Setup

You need Neovim 0.10+. The tests need nothing else. For the rest:
[stylua](https://github.com/JohnnyMorganz/StyLua) 2.3.1 for formatting,
[vhs](https://github.com/charmbracelet/vhs) for the demos, and whichever
renderers you want to try.

```sh
make dev           # Neovim with this checkout on the runtimepath, no user config
make test          # headless checks, no renderer needed
make format        # stylua, see stylua.toml
make format-check  # what CI runs
make demo          # record the missing demo/*.gif, needs vhs
```

Tests print one line per check. `doc/beside.txt` is written by hand, and the
README repeats its config and renderer sections, so update all three with the
code.

## How I work on it

Most of my time goes into `make dev`. It starts Neovim with `--clean` and this
checkout first on the runtimepath, so you get the plugin and nothing from your
own config. From there:

```vim
:e demo/sample.md
:Beside
:Beside glow          " force a renderer
:checkhealth beside   " what's installed and what each filetype resolves to
```

Lua caches modules once they're loaded, so after editing the code I quit and
run `make dev` again. It starts fast enough that this is less annoying than it
sounds.

To try a renderer before touching any code, add it from the command line:

```vim
:lua require('beside').setup({ renderers = { mdcat = { filetypes = { markdown = true }, command = function(c) return { 'mdcat', '--columns', tostring(c.width), '-' } end } } })
:Beside mdcat
```

## Code layout

- `lua/beside/init.lua`: setup, config, the preview window and the sync
- `lua/beside/renderers.lua`: the renderer contract and the builtins
- `lua/beside/ansi.lua`: ANSI escapes to text and styles
- `lua/beside/anchors.lua`: matching source lines to rendered lines
- `lua/beside/health.lua`: `:checkhealth beside`
- `plugin/beside.lua`: the `:Beside` command
- `test/run.lua`: the headless checks
- `demo/`: vhs tapes and sample documents for the README gifs

## Adding a renderer

A renderer is a table: the filetypes it renders, and a function returning the
command that reads the document on stdin and prints ANSI-colored text. The
[README](README.md#adding-a-renderer) has the full contract. Adding one as a
builtin takes these steps:

1. **The entry.** Add it to `lua/beside/renderers.lua`, with a one-line comment
   above it naming the tool and linking to it. The existing entries are the
   template; yours should look like them.
2. **The filetype.** Neovim has to know the filetype. If it doesn't yet, add it
   in `plugin/beside.lua`, the way Carve is.
3. **The tests.** `test/run.lua` checks `:Beside` completion against the list
   of builtin names; add yours, then `make test`.
4. **The docs.** Add a row to the table under "Supported renderers" in the
   README, and name the renderer in `doc/beside.txt` (the intro and the
   `renderers` comment in the config).
5. **A demo tape.** See below.

If your renderer handles a filetype that already has one, leave `prefer` alone
unless there's a good reason to change the default. People can opt in.

## The demo tape

Every renderer gets a vhs tape in `demo/`. It's the closest thing this project
has to an end-to-end test: it opens real Neovim, runs the real renderer,
scrolls through a document, and the gif shows whether colors, width and sync
hold up. If the recording looks wrong, something is wrong.

1. Add a sample document, `demo/sample.<ext>`. Put in the things that change
   line count, so the sync has work to do: headings, lists, a table, a code
   block, a long paragraph.
2. Copy `demo/carve.tape` to `demo/<name>.tape` and change `Output`,
   `Require` and the file it opens. Keep `Source demo/settings.tape` (shared
   size, font and theme) and `-u demo/init.lua` (the editor settings for the
   recordings).
3. Register the gif on the `demo:` line of the Makefile:

   ```make
   demo: demo/markdown.gif demo/rst.gif demo/carve.gif demo/renderers.gif demo/<name>.gif
   ```

4. Run `make demo` from the repo root. It only records gifs that don't exist
   yet; to redo one, delete it or run `make -B demo/<name>.gif`.
5. Add the gif to the README, below the renderers table, with the others.

## Renderer quirks

These are the things that tend to bite, roughly in the order I run into them.

- **No colors.** beside runs the renderer through a pipe, not a terminal, and
  plenty of tools drop colors when stdout isn't a TTY. Look for a flag or an
  environment variable that forces them; glow's entry sets `CLICOLOR_FORCE=1`
  in `env` for this. To check, run
  `tool < demo/sample.md | cat -v`; you should see `^[[` sequences.
- **Only color escapes survive.** The preview understands SGR (`ESC[...m`):
  colors, bold, dim, italic, underline, reverse and strikethrough. Other SGR
  attributes are dropped, and OSC hyperlinks are stripped. Cursor movement,
  screen clears or a pager show up as garbage, or the render hangs. Turn off
  paging and anything interactive.
- **Colors against the theme.** The 16 base colors come from the colorscheme's
  terminal colors, so they follow the user's theme. 256-color and truecolor
  output is shown exactly as the renderer picks it, and a style made for a dark
  terminal can be unreadable on a light background. `context.background` is
  `light` or `dark`; glow uses it to pick its style.
- **Width.** Pass `context.width` to whatever width flag the tool has. It's
  the preview window's width minus one column, never less than 20, and beside
  re-renders when the window is resized. Tables and code block frames are
  where renderers overflow, and the preview then wraps them mid-border, so
  check that nothing goes past the width. If the tool takes no width at all,
  like carve, the preview wraps long lines; say so in the entry's comment.
- **stdin.** The document arrives on stdin, not as a file, which is how unsaved
  edits get rendered. Many tools need `-` to read from stdin.
- **Failures.** A non-zero exit shows the exit code and stderr in the preview,
  which is usually enough to see what went wrong.
- **Sync drift.** Sync looks for each source line's text in the output.
  Renderers that keep the text as written sync best; smart quotes, reflowed
  words or heavy rewriting make the preview drift. It's a heuristic, so a
  line or two off inside a paragraph is expected.

## Using AI

Use whatever tools help you; I do too. Things are changing fast and we'll
figure it out as we go. The one rule: if you open a pull request, it's yours,
not the AI's. Read it, run it, and be ready to talk about it.

## Pull requests

- `make test` and `make format-check` pass. CI runs both.
- One renderer or one fix per pull request.
- Commit subjects are plain sentences saying what changed, like
  "Add the mdcat renderer".
- Follow the style of the file you're in. The Lua follows the mini.nvim shape:
  one statement per line, full names, short comments that say why.
