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

# Record the README demos into demo/*.gif
demo:
	$(VHS) demo/markdown.tape
	$(VHS) demo/rst.tape
	$(VHS) demo/renderers.tape

.PHONY: test dev format format-check demo
