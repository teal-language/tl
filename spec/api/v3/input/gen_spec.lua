local util = require("spec.util")
local teal = require("teal")

describe("Input.gen", function()
   it("can generate Lua from Teal", function()
      local tl_code = [[
         local function add(x: integer, y: integer): integer
            return x + y
         end
         print(add(1, 2))
      ]]

      local expected_lua_code = [[
         local function add(x, y)
            return x + y
         end
         print(add(1, 2))
      ]]

      local compiler = teal.compiler()
      local input = compiler:input(tl_code)
      local result_lua_code, mod, check_err = input:gen()

      assert(mod)
      assert.same({}, check_err.syntax_errors)
      assert.same({}, check_err.type_errors)
      assert.same({}, check_err.warnings)
      util.assert_line_by_line(expected_lua_code, result_lua_code)
   end)

   it("does not generate Lua from invalid Teal", function()
      local tl_code = [[
         local function add(x: integer, y: integer): integer
            return x + y
      ]]

      local compiler = teal.compiler()
      local input = compiler:input(tl_code)
      local result_lua_code, mod, check_err = input:gen()

      assert.is_nil(mod)
      assert.same(1, #check_err.syntax_errors)
      assert.same(0, #check_err.type_errors)
      assert.same(0, #check_err.warnings)
   end)
end)
