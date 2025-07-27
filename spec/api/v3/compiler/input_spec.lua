local util = require("spec.util")
local teal = require("teal")

describe("Compiler.input", function()
   it("can read Teal strings", function()
      local tl_code = [[
         local movie:string = "Star Wars: Episode"
         local episode: number = 4
      ]]

      local expected_lua_code = [[
         local movie = "Star Wars: Episode"
         local episode = 4
      ]]

      local compiler = teal.compiler()
      local input = compiler:input(tl_code)
      local result_lua_code = input:gen()

      util.assert_line_by_line(expected_lua_code, result_lua_code)
   end)
end)
