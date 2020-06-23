rockspec_format = "3.0"
package = "tl"
version = "dev-1"
source = {
   url = "git://github.com/teal-language/tl"
}
description = {
   summary = "Teal, a typed dialect of Lua",
   homepage = "https://github.com/teal-language/tl",
   license = "MIT",
}
dependencies = {
   -- this is really an optional dependency if you're running Lua 5.3,
   -- but if you're using LuaRocks, pulling it shouldn't be too much
   -- trouble anyway.
   "compat53",

   -- needed for the cli tool
   "argparse",

   -- needed for build options
   -- --build-dir, --source-dir, etc.
   "luafilesystem",
}
build = {
   modules = {
      tl = "tl.lua",
   },
   install = {
      bin = {
         "tl"
      },
      lua = {
         "tl.tl"
      }
   },
}
