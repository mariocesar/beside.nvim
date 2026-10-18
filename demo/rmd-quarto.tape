# Preview R Markdown, then open a Quarto document and the preview moves along; both rendered by leaf
Output demo/rmd-quarto.gif
Require nvim
Require leaf
Source demo/settings.tape

Hide
Type "nvim --clean -u demo/init.lua demo/sample.Rmd" Enter
Sleep 1s
Show

Sleep 1s
Type ":Beside" Sleep 400ms Enter
Sleep 2s

Down@120ms 30
Sleep 1s
Ctrl+D Sleep 800ms
Ctrl+D Sleep 1.5s

# Opening another document moves the preview to it
Type ":e demo/sample.qmd" Sleep 400ms Enter
Sleep 2.5s
Down@120ms 24
Sleep 1s
Ctrl+D Sleep 2s
