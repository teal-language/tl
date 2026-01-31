rockspec_format = "3.0"
package = "tl"
version = "dev-1"
source = {
   url = "git+https://github.com/teal-language/tl"
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
   "compat53 >= 0.11",

   -- needed for the CLI tool
   "argparse",
   "luafilesystem",
}
test_dependencies = {
   "dkjson",
}
build = {
   modules = {
      -- Ship the compiled Lua module `tl` for API compatibility:
      tl = "tl.lua",

      -- Ship the compiled Lua modules from the `teal` namespace for runtime use:
      ["teal.debug"] = "teal/debug.lua",
      ["teal.loader"] = "teal/loader.lua",
      ["teal.input"] = "teal/input.lua",
      ["teal.variables"] = "teal/variables.lua",
      ["teal.type_errors"] = "teal/type_errors.lua",
      ["teal.package_loader"] = "teal/package_loader.lua",
      ["teal.parser"] = "teal/parser.lua",
      ["teal.types"] = "teal/types.lua",
      ["teal.traversal"] = "teal/traversal.lua",
      ["teal.metamethods"] = "teal/metamethods.lua",
      ["teal.api.v2"] = "teal/api/v2.lua",
      ["teal.api.v1"] = "teal/api/v1.lua",
      ["teal.type_reporter"] = "teal/type_reporter.lua",
      ["teal.attributes"] = "teal/attributes.lua",
      ["teal.check.type_checker"] = "teal/check/type_checker.lua",
      ["teal.check.special_functions"] = "teal/check/special_functions.lua",
      ["teal.check.context"] = "teal/check/context.lua",
      ["teal.check.require_file"] = "teal/check/require_file.lua",
      ["teal.check.check"] = "teal/check/check.lua",
      ["teal.check.node_checker"] = "teal/check/node_checker.lua",
      ["teal.check.relations"] = "teal/check/relations.lua",
      ["teal.check.visitors"] = "teal/check/visitors.lua",
      ["teal.precompiled.default_env"] = "teal/precompiled/default_env.lua",
      ["teal.gen.targets"] = "teal/gen/targets.lua",
      ["teal.gen.lua_compat"] = "teal/gen/lua_compat.lua",
      ["teal.gen.lua_generator"] = "teal/gen/lua_generator.lua",
      ["teal.errors"] = "teal/errors.lua",
      ["teal.environment"] = "teal/environment.lua",
      ["teal.macroexps"] = "teal/macroexps.lua",
      ["teal.init"] = "teal/init.lua",
      ["teal.facts"] = "teal/facts.lua",
      ["teal.lexer"] = "teal/lexer.lua",
      ["teal.util"] = "teal/util.lua",
      ["teal.contextual_typing"] = "teal/contextual_typing.lua",
      ["teal.contextual_type_checker"] = "teal/contextual_type_checker.lua",

      -- Ship the compiled Lua modules from the `tlcli` namespace for the `tl` program:
      ["tlcli.commands.warnings"] = "tlcli/commands/warnings.lua",
      ["tlcli.commands.types"] = "tlcli/commands/types.lua",
      ["tlcli.commands.gen"] = "tlcli/commands/gen.lua",
      ["tlcli.commands.check"] = "tlcli/commands/check.lua",
      ["tlcli.commands.run"] = "tlcli/commands/run.lua",
      ["tlcli.report"] = "tlcli/report.lua",
      ["tlcli.driver"] = "tlcli/driver.lua",
      ["tlcli.configuration"] = "tlcli/configuration.lua",
      ["tlcli.main"] = "tlcli/main.lua",
      ["tlcli.common"] = "tlcli/common.lua",
      ["tlcli.perf"] = "tlcli/perf.lua",
   },
   install = {
      bin = {
         -- Ship the `tl` CLI program:
         "tl"
      },

      lua = {
         -- Ship the `tl` Teal module for API compatibility:
         "tl.tl",

         -- Ship the Teal modules in the `teal` namespace for requiring the Teal API:
         ["teal.debug"] = "teal/debug.tl",
         ["teal.loader"] = "teal/loader.tl",
         ["teal.input"] = "teal/input.tl",
         ["teal.variables"] = "teal/variables.tl",
         ["teal.type_errors"] = "teal/type_errors.tl",
         ["teal.package_loader"] = "teal/package_loader.tl",
         ["teal.parser"] = "teal/parser.tl",
         ["teal.types"] = "teal/types.tl",
         ["teal.traversal"] = "teal/traversal.tl",
         ["teal.metamethods"] = "teal/metamethods.tl",
         ["teal.api.v2"] = "teal/api/v2.tl",
         ["teal.api.v1"] = "teal/api/v1.tl",
         ["teal.type_reporter"] = "teal/type_reporter.tl",
         ["teal.attributes"] = "teal/attributes.tl",
         ["teal.check.type_checker"] = "teal/check/type_checker.tl",
         ["teal.check.special_functions"] = "teal/check/special_functions.tl",
         ["teal.check.context"] = "teal/check/context.tl",
         ["teal.check.require_file"] = "teal/check/require_file.tl",
         ["teal.check.check"] = "teal/check/check.tl",
         ["teal.check.node_checker"] = "teal/check/node_checker.tl",
         ["teal.check.relations"] = "teal/check/relations.tl",
         ["teal.check.visitors"] = "teal/check/visitors.tl",
         ["teal.gen.targets"] = "teal/gen/targets.tl",
         ["teal.gen.lua_compat"] = "teal/gen/lua_compat.tl",
         ["teal.gen.lua_generator"] = "teal/gen/lua_generator.tl",
         ["teal.errors"] = "teal/errors.tl",
         ["teal.environment"] = "teal/environment.tl",
         ["teal.macroexps"] = "teal/macroexps.tl",
         ["teal.init"] = "teal/init.tl",
         ["teal.facts"] = "teal/facts.tl",
         ["teal.lexer"] = "teal/lexer.tl",
         ["teal.util"] = "teal/util.tl",
         ["teal.contextual_typing"] = "teal/contextual_typing.tl",
         ["teal.contextual_type_checker"] = "teal/contextual_type_checker.tl",
         ["teal.precompiled.default_env"] = "teal/precompiled/default_env.d.tl",
         ["teal.default.prelude"] = "teal/default/prelude.d.tl",
         ["teal.default.stdlib"] = "teal/default/stdlib.d.tl",
      }
   },
}
