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
      --[[ Generated via
           find teal -name '*.tl' | sort | awk '!/^teal\/default\//{
             module = $0
             path = $0
             gsub("(\\.d)?\\.tl$", ".lua", path)
             gsub("\\.tl$", "", module)
             gsub("\\.d$", "", module)
             gsub("/", ".", module)
             print "[\"" module "\"] = \"" path "\","
           }'
      ]]
      ["teal.api.v1"] = "teal/api/v1.lua",
      ["teal.api.v2"] = "teal/api/v2.lua",
      ["teal.ast"] = "teal/ast.lua",
      ["teal.attributes"] = "teal/attributes.lua",
      ["teal.block"] = "teal/block.lua",
      ["teal.check.check"] = "teal/check/check.lua",
      ["teal.check.context"] = "teal/check/context.lua",
      ["teal.check.node_checker"] = "teal/check/node_checker.lua",
      ["teal.check.relations"] = "teal/check/relations.lua",
      ["teal.check.require_file"] = "teal/check/require_file.lua",
      ["teal.check.special_functions"] = "teal/check/special_functions.lua",
      ["teal.check.type_checker"] = "teal/check/type_checker.lua",
      ["teal.check.visitors"] = "teal/check/visitors.lua",
      ["teal.debug"] = "teal/debug.lua",
      ["teal.environment"] = "teal/environment.lua",
      ["teal.errors"] = "teal/errors.lua",
      ["teal.facts"] = "teal/facts.lua",
      ["teal.gen.lua_compat"] = "teal/gen/lua_compat.lua",
      ["teal.gen.lua_generator"] = "teal/gen/lua_generator.lua",
      ["teal.gen.targets"] = "teal/gen/targets.lua",
      ["teal.init"] = "teal/init.lua",
      ["teal.input"] = "teal/input.lua",
      ["teal.lexer"] = "teal/lexer.lua",
      ["teal.loader"] = "teal/loader.lua",
      ["teal.macro_eval"] = "teal/macro_eval.lua",
      ["teal.macroexps"] = "teal/macroexps.lua",
      ["teal.metamethods"] = "teal/metamethods.lua",
      ["teal.package_loader"] = "teal/package_loader.lua",
      ["teal.parser"] = "teal/parser.lua",
      ["teal.precompiled.default_env"] = "teal/precompiled/default_env.lua",
      ["teal.reader"] = "teal/reader.lua",
      ["teal.traversal"] = "teal/traversal.lua",
      ["teal.type_errors"] = "teal/type_errors.lua",
      ["teal.type_reporter"] = "teal/type_reporter.lua",
      ["teal.types"] = "teal/types.lua",
      ["teal.util"] = "teal/util.lua",
      ["teal.variables"] = "teal/variables.lua",


      -- Ship the compiled Lua modules from the `tlcli` namespace for the `tl` program:
      ["tlcli.commands.dump_blocks"] = "tlcli/commands/dump_blocks.lua",
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
         --[[ Generated via
              find teal -name '*.tl' | sort | awk '{
                path = $0
                gsub("\\.tl$", "")
                gsub("/", ".")
                gsub("\\.d$", "")
                print "[\"" $0 "\"] = \"" path "\","
              }'
         ]]
         ["teal.api.v1"] = "teal/api/v1.tl",
         ["teal.api.v2"] = "teal/api/v2.tl",
         ["teal.ast"] = "teal/ast.tl",
         ["teal.attributes"] = "teal/attributes.tl",
         ["teal.block"] = "teal/block.tl",
         ["teal.check.check"] = "teal/check/check.tl",
         ["teal.check.context"] = "teal/check/context.tl",
         ["teal.check.node_checker"] = "teal/check/node_checker.tl",
         ["teal.check.relations"] = "teal/check/relations.tl",
         ["teal.check.require_file"] = "teal/check/require_file.tl",
         ["teal.check.special_functions"] = "teal/check/special_functions.tl",
         ["teal.check.type_checker"] = "teal/check/type_checker.tl",
         ["teal.check.visitors"] = "teal/check/visitors.tl",
         ["teal.debug"] = "teal/debug.tl",
         ["teal.default.prelude"] = "teal/default/prelude.d.tl",
         ["teal.default.stdlib"] = "teal/default/stdlib.d.tl",
         ["teal.environment"] = "teal/environment.tl",
         ["teal.errors"] = "teal/errors.tl",
         ["teal.facts"] = "teal/facts.tl",
         ["teal.gen.lua_compat"] = "teal/gen/lua_compat.tl",
         ["teal.gen.lua_generator"] = "teal/gen/lua_generator.tl",
         ["teal.gen.targets"] = "teal/gen/targets.tl",
         ["teal.init"] = "teal/init.tl",
         ["teal.input"] = "teal/input.tl",
         ["teal.lexer"] = "teal/lexer.tl",
         ["teal.loader"] = "teal/loader.tl",
         ["teal.macro_eval"] = "teal/macro_eval.tl",
         ["teal.macroexps"] = "teal/macroexps.tl",
         ["teal.metamethods"] = "teal/metamethods.tl",
         ["teal.package_loader"] = "teal/package_loader.tl",
         ["teal.parser"] = "teal/parser.tl",
         ["teal.precompiled.default_env"] = "teal/precompiled/default_env.d.tl",
         ["teal.reader"] = "teal/reader.tl",
         ["teal.traversal"] = "teal/traversal.tl",
         ["teal.type_errors"] = "teal/type_errors.tl",
         ["teal.type_reporter"] = "teal/type_reporter.tl",
         ["teal.types"] = "teal/types.tl",
         ["teal.util"] = "teal/util.tl",
         ["teal.variables"] = "teal/variables.tl",
      }
   },
}
