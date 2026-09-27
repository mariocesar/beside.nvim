# Preview Carve, rendered by carve
Output demo/carve.gif
Require nvim
Require carve
Source demo/settings.tape

Hide
Type "nvim --clean -u demo/init.lua demo/sample.crv" Enter
Sleep 1s
Show

Sleep 1s
Type ":Beside" Sleep 400ms Enter
Sleep 2s

Down@120ms 30
Sleep 1s
Ctrl+D Sleep 800ms
Ctrl+D Sleep 1.5s
Type "gg" Sleep 2s
