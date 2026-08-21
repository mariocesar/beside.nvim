NVIM ?= nvim

test:
	$(NVIM) --clean --headless -c 'luafile test/run.lua'

dev:
	$(NVIM) --clean --cmd 'set rtp^=.'

.PHONY: test dev
