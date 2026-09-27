NVIM ?= nvim
STYLUA ?= stylua
VHS ?= vhs

test:
	$(NVIM) --clean --headless -c 'luafile test/run.lua'

dev:
	$(NVIM) --clean --cmd 'set rtp^=.'

format:
	$(STYLUA) lua plugin test

format-check:
	$(STYLUA) --check lua plugin test

demo: demo/markdown.gif demo/rst.gif demo/carve.gif demo/renderers.gif

demo/%.gif: | demo/%.tape
	$(VHS) $|

.PHONY: test dev format format-check demo
