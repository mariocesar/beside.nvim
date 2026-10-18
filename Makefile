NVIM ?= nvim
STYLUA ?= stylua
VHS ?= vhs
GH ?= gh

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

# A version's section of CHANGES.md, prepared for Github Release text.
notes:
	@awk -v v=$(V) '/^## /{p=($$2==v); next} p' CHANGES.md \
		| $(NVIM) \
			--clean \
			--headless \
			'+silent %s/\S\zs\n\s*\ze[^-[:space:]]/ /e' \
			'+silent w! /dev/stdout' '+q!' \
			-

# Check, tag, push and create the GitHub release: make release V=v0.2.2
release: test format-check
	@test -n "$(V)" || { echo 'usage: make release V=v0.2.2'; exit 1; }
	@git diff --quiet HEAD || { echo 'commit your changes first'; exit 1; }
	@$(MAKE) -s notes V=$(V) | grep -q . || { echo 'no $(V) section in CHANGES.md'; exit 1; }
	git tag $(V)
	git push origin HEAD $(V)
	$(MAKE) -s notes V=$(V) | $(GH) release create $(V) --title $(V) --notes-file -

.PHONY: test dev format format-check demo notes release
