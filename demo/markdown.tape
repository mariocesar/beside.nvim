# Open a markdown document, preview it, scroll both sides, edit
Output demo/markdown.gif
Require nvim
Require leaf
Source demo/settings.tape

Hide
Type "nvim --clean -u demo/init.lua demo/guide.md" Enter
Sleep 1s
Show

Sleep 1s
Type ":Beside" Sleep 400ms Enter
Sleep 2s

# Moving in the source moves the preview
Down@120ms 30
Sleep 1s
Ctrl+D Sleep 800ms
Ctrl+D Sleep 800ms
Ctrl+D Sleep 1.5s

# Scrolling the preview scrolls the source
Ctrl+W Type "l" Sleep 500ms
Ctrl+U Sleep 800ms
Ctrl+U Sleep 800ms
Ctrl+U Sleep 800ms
Sleep 1s
Ctrl+W Type "h" Sleep 500ms

# Edits re-render as you type
Type "/watch mode" Sleep 300ms Enter
Sleep 600ms
Type "o- [ ] A preview beside the editor" Escape
Sleep 2.5s
