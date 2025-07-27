local util = require("spec.util")
local teal = require("teal")

describe("Compiler.open", function()
   it("should cache modules by filename to prevent code being loaded more than once (#245)", function()

      local current_dir = lfs.currentdir()
      local dir_name = util.write_tmp_dir(finally, {
         ["foo.tl"] = [[ require("bar") ]],
         ["bar.tl"] = [[ global x = 10 ]],
      })

      assert(lfs.chdir(dir_name))

      local compiler = teal.compiler()

      local foo_input = compiler:open("foo.tl")
      local foo_lua, foo_module, foo_err = foo_input:gen()

      local bar_input = compiler:open("bar.tl")
      local bar_lua, bar_module, bar_err = bar_input:gen()

      assert(lfs.chdir(current_dir))
      assert(foo_lua)
      assert(bar_lua)
      assert(foo_module)
      assert(bar_module)
      assert(#foo_err.syntax_errors == 0)
      assert(#foo_err.type_errors == 0)
      assert(#bar_err.syntax_errors == 0)
      assert(#bar_err.type_errors == 0)
   end)

   it("should strip BOM from files", function()
      local bom = "\239\187\191"
      local current_dir = lfs.currentdir()
      local dir_name = util.write_tmp_dir(finally, {
         ["main.tl"] = bom .. [[
            return "working"
         ]],
      })
      local expected_lua_code = [[
         return "working"
      ]]

      local compiler = teal.compiler()
      assert(lfs.chdir(dir_name))
      local input = compiler:open("main.tl")
      assert(lfs.chdir(current_dir))
      local code, mod, err = input:gen()
      util.assert_line_by_line(expected_lua_code, code)
   end)

end)
