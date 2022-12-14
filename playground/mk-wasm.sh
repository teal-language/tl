#!/bin/sh
destFolder=./
srcFolder="/home/mingo/dev/lua/tl-dad/"
argparseFolder="/home/mingo/dev/lua/argparse/src/"
emsdk-env emcc  \
	-Os -DMAKE_LUA_WASM -DLUA_PROGNAME='"lua"' \
	-DLUA_COMPAT_5_3 -DLUA_USE_LINUX -D_XOPEN_SOURCE=500 \
	-DWITH_LPEGLABEL -DWITH_LUAFILESYSTEM -DMAKE_LUA_CMD -DMAKE_LUAC_CMD \
	-o teal-lua-playground.js am-lua-5.4.4.c \
	-sEXPORTED_FUNCTIONS=_main,_lua_main,_luac_main,_free,_malloc \
	-sEXPORTED_RUNTIME_METHODS=ccall,cwrap,FS,callMain,setValue \
	-sALLOW_MEMORY_GROWTH -s INVOKE_RUN=0 -s EXIT_RUNTIME=0 \
	--embed-file $HOME/dev/lua/lpeglabel/relabel.lua@$destFolder \
	--embed-file $HOME/dev/lua/lpegrex/lpegrex.lua@$destFolder \
	--embed-file $argparseFolder/argparse.lua@$destFolder \
	--embed-file $srcFolder/tl.lua@$destFolder \
	--embed-file $srcFolder/tl@$destFolder

