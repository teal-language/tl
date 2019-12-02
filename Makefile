all:
	./tl tl.tl
	cp tl.lua tl.lua.bak
	./tl gen tl.tl && cp tl.lua tl.lua.1 || { cp tl.lua.bak tl.lua; exit 1; }
	./tl gen tl.tl && cp tl.lua tl.lua.2 || { cp tl.lua.bak tl.lua; exit 1; }
	diff tl.lua.1 tl.lua.2
	busted -v

cov:
	rm -f luacov.stats.out luacov.report.out
	busted -c
	luacov tl.lua
	cat luacov.report.out
