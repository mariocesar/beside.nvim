NVIM ?= nvim
STYLUA ?= stylua

test:
	$(NVIM) --clean --headless -c 'luafile test/run.lua'

dev:
	$(NVIM) --clean --cmd 'set rtp^=.'

format:
	$(STYLUA) lua plugin test

format-check:
	$(STYLUA) --check lua plugin test

.PHONY: test dev format format-check
