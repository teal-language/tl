all:
	cp tl.lua tl.lua.bak
	lua_no_tailcalls tl2lua.lua tl.tl > tl.lua.1 && cp tl.lua.1 tl.lua
	lua_no_tailcalls tl2lua.lua tl.tl > tl.lua.2 || { cp tl.lua.bak tl.lua; exit 1; }
	diff tl.lua.1 tl.lua.2
	busted

