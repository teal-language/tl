local tl = require("tl")
local util = require("spec.util")

describe("tl.process", function()
   describe("tl.process_string", function()
      it("can process tl strings", function()
         local tl_code = [[
            local movie:string = "Star Wars: Episode"
            local episode: number = 4
         ]]

         local expected_lua_code = [[
            local movie = "Star Wars: Episode"
            local episode = 4
         ]]

         local result = tl.process_string(tl_code)
         local pretty_result_string = tl.pretty_print_ast(result.ast)

         util.assert_line_by_line(expected_lua_code, pretty_result_string)
      end)
   end)
end)
