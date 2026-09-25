# The same markdown document with leaf, then glow
Output demo/renderers.gif
Require nvim
Require leaf
Require glow
Source demo/settings.tape

Hide
Type "nvim --clean -u demo/init.lua demo/guide.md" Enter
Sleep 1s
Show

Sleep 1s
Type ":Beside leaf" Sleep 400ms Enter
Sleep 2s
Type "22j" Sleep 2s

Type ":Beside glow" Sleep 400ms Enter
Sleep 2.5s
Type "22k" Sleep 2s
