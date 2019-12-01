rockspec_format = "3.0"
package = "tl"
version = "dev-1"
source = {
   url = "git://github.com/hishamhm/tl"
}
description = {
   summary = "A typed dialect of Lua",
   homepage = "https://github.com/hishamhm/tl",
}
dependencies = {
   -- this is really an optional dependency if you're running Lua 5.3,
   -- but if you're using LuaRocks, pulling it shouldn't be too much
   -- trouble anyway.
   "compat53",
}
build = {
   modules = {
      tl = "tl.lua",
   },
   install = {
      bin = {
         "tl"
      }
   },
}
