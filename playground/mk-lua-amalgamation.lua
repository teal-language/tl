local lua_51 = [==[
lapi.c
lauxlib.c
lbaselib.c
lcode.c
ldblib.c
ldebug.c
ldo.c
ldump.c
lfunc.c
lgc.c
linit.c
liolib.c
llex.c
lmathlib.c
lmem.c
loadlib.c
lobject.c
lopcodes.c
loslib.c
lparser.c
lstate.c
lstring.c
lstrlib.c
ltable.c
ltablib.c
ltm.c
lundump.c
lvm.c
lzio.c
print.c
bitlib.c
]==]

local lua_52 = [==[
lapi.c
lcode.c
lctype.c
ldebug.c
ldo.c
ldump.c
lfunc.c
lgc.c
llex.c
lmem.c
lobject.c
lopcodes.c
lparser.c
lstate.c
lstring.c
ltable.c
ltm.c
lundump.c
lvm.c
lzio.c
lauxlib.c
lbaselib.c
lbitlib.c
lcorolib.c
ldblib.c
liolib.c
lmathlib.c
loslib.c
lstrlib.c
ltablib.c
loadlib.c
linit.c
]==]

local lua_53 = [==[
lapi.c
lcode.c
lctype.c
ldebug.c
ldo.c
ldump.c
lfunc.c
lgc.c
llex.c
lmem.c
lobject.c
lopcodes.c
lparser.c
lstate.c
lstring.c
ltable.c
ltm.c
lundump.c
lvm.c
lzio.c
lauxlib.c
lbaselib.c
lbitlib.c
lcorolib.c
ldblib.c
liolib.c
lmathlib.c
loslib.c
lstrlib.c
ltablib.c
lutf8lib.c
loadlib.c
linit.c
]==]

local lua_54 = [==[
lapi.c
lcode.c
lctype.c
ldebug.c
ldo.c
ldump.c
lfunc.c
lgc.c
llex.c
lmem.c
lobject.c
lopcodes.c
lparser.c
lstate.c
lstring.c
ltable.c
ltm.c
lundump.c
lvm.c
lzio.c
lauxlib.c
lbaselib.c
lcorolib.c
ldblib.c
liolib.c
lmathlib.c
loadlib.c
loslib.c
lstrlib.c
ltablib.c
lutf8lib.c
linit.c
]==]

local lpeglabel_prefix = "/home/mingo/dev/lua/lpeglabel/"
local lpeglabel = [==[
lplvm.c
lplcap.c
lpltree.c
lplcode.c
lplprint.c
]==]

local luafilesystem_prefix = "/home/mingo/dev/lua/luafilesystem/src/"
local luafilesystem = [==[
lfs.c
]==]

local included = {}
local inc_sys = {}
local inc_sys_count = 0
local out = io.stdout

function setIncluded(ilist)
	for i,v in ipairs(ilist) do included[v] = 0 end
end

function CopyWithInline(prefix, filename)
	if included[filename] then return end
	included[filename] = true
	print('//--Start of', filename);
	--if(filename:match("luac?.c"))
	local inp = assert(io.open(prefix .. filename, "r"))
	for line in inp:lines() do
		if line:match('#define LUA_USE_READLINE') then
			out:write("//" .. line .. "\n")
		else
			local inc = line:match('#include%s+(["<].-)[">]')
			if inc  then
				out:write("//" .. line .. "\n")
				if inc:sub(1,1) == '"' then
					CopyWithInline(prefix, inc:sub(2))
				else
					local fn = inc:sub(2)
					if inc_sys[fn] == null then
						inc_sys_count = inc_sys_count +1
						inc_sys[fn] = inc_sys_count
					end
				end
			else
				out:write(line .. "\n")
			end
		end
      end
	print('//--End of', filename);
end

print([==[
#include "cosmopolitan.h"
#define loslib_c
#define lua_c
#define lobject_c
#define LUA_USE_MKSTEMP
#define LUA_USE_POSIX
]==])

--local prefix = '/home/mingo/dev/lua/lua-5.1.5/src/'; local lua_files = lua_51;
--local prefix = '/home/mingo/dev/lua/lua-5.2.4/src/'; local lua_files = lua_52;
--local prefix = '/home/mingo/dev/lua/lua-5.3.6/src/'; local lua_files = lua_53;
local prefix = '/home/mingo/dev/lua/lua-5.4.4/src/'; local lua_files = lua_54;
--for filename in lua_files:gmatch('#include "([^"]+)"') do
for filename in lua_files:gmatch('([^\n]+)') do
	CopyWithInline(prefix, filename);
end
print('#ifdef WITH_LPEGLABEL')
print('#define Instruction Instruction_lpeg')
print('#define match match_lpeg')
print('#define utf8_decode utf8_decode_lpeg')
print('#define finaltarget finaltarget_lpeg')
print('#define codenot codenot_lpeg')
for filename in lpeglabel:gmatch('([^\n]+)') do
	CopyWithInline(lpeglabel_prefix, filename);
end
print('#undef codenot')
print('#undef finaltarget')
print('#undef utf8_decode')
print('#undef match')
print('#undef Instruction')
print('#endif //WITH_LPEGLABEL')
print('#ifdef WITH_LUAFILESYSTEM')
for filename in luafilesystem:gmatch('([^\n]+)') do
	CopyWithInline(luafilesystem_prefix, filename);
end
print('#endif //WITH_LUAFILESYSTEM')
print('#ifdef MAKE_LUA_CMD')
print([==[
#if defined(WITH_LPEGLABEL) && defined(WITH_LUAFILESYSTEM)
LUALIB_API void my_luaL_openlibs (lua_State *L) {
  luaL_openlibs(L);
	luaL_requiref(L, "lpeglabel", luaopen_lpeglabel, 1);
	lua_pop(L, 1);  /* remove lib */
	luaL_requiref(L, "lfs", luaopen_lfs, 1);
	lua_pop(L, 1);  /* remove lib */
}
#define luaL_openlibs my_luaL_openlibs
#endif
#define main lua_main
#define pmain lua_pmain
#define progname lua_progname
#define writer lua_writer
#define msghandler lua_msghandler
]==])
CopyWithInline(prefix, "lua.c")
print([==[
#if defined(WITH_LPEGLABEL) && defined(WITH_LSQLITE3)
#undef my_luaL_openlibs
#endif
#undef main
#undef pmain
#undef progname
#undef writer
#undef msghandler
]==])
print('#endif //MAKE_LUA_CMD')
print('#ifdef MAKE_LUAC_CMD')
print([==[
#define main luac_main
#define pmain luac_pmain
#define progname luac_progname
#define writer luac_writer
#define msghandler luac_msghandler
]==])
CopyWithInline(prefix, "luac.c")
print([==[
#undef main
#undef pmain
#undef progname
#undef writer
#undef msghandler
]==])
print('#endif //MAKE_LUAC_CMD')
print([==[
#ifdef MAKE_LUA_WASM
int main(int argc, char *argv[]) {
		printf("Dummy main for wasm\n");
		return 0;
}
#endif //MAKE_LUA_WASM
]==])
for k, v in pairs(inc_sys) do print("#include <" .. k .. "> //" .. v ) end