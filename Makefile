LUA ?=

ifeq ($(OS), Windows_NT)
	BUSTED = busted.bat --suppress-pending --exclude-tags=unix
else
	BUSTED = busted --suppress-pending
endif

all: selfbuild suite

selfbuild:
	cp tl.lua tl.lua.bak
	$(LUA) ./tl gen --check tl.tl && cp tl.lua tl.lua.1 || { cp tl.lua tl.lua.1; cp tl.lua.bak tl.lua; exit 1; }
	$(LUA) ./tl gen --check tl.tl && cp tl.lua tl.lua.2 || { cp tl.lua tl.lua.2; cp tl.lua.bak tl.lua; exit 1; }
	diff tl.lua.1 tl.lua.2

suite:
	${BUSTED} -v $(TESTFLAGS)

cov:
	rm -f luacov.stats.out luacov.report.out
	${BUSTED} -c
	luacov tl.lua
	cat luacov.report.out
