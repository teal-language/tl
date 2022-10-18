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
   describe("process", function()
      it("should cache modules by filename to prevent code being loaded more than once (#245)", function()

         local current_dir = lfs.currentdir()
         local dir_name = util.write_tmp_dir(finally, {
            ["foo.tl"] = [[ require("bar") ]],
            ["bar.tl"] = [[ global x = 10 ]],
         })

         assert(lfs.chdir(dir_name))
         local foo_result, foo_err = tl.process("foo.tl")
         local bar_result, bar_err = tl.process("bar.tl", foo_result.env)
         assert(lfs.chdir(current_dir))
         assert(foo_result, foo_err)
         assert(bar_result, bar_err)
      end)
      it("should strip BOM from files", function()

         local bom = "\xEF\xBB\xBF"
         local current_dir = lfs.currentdir()
         local dir_name = util.write_tmp_dir(finally, {
            ["main.tl"] = bom .. [[
               return "working"
            ]],
         })
         local expected_lua_code = [[
            return "working"
         ]]

         assert(lfs.chdir(dir_name))
         local result, err = tl.process("main.tl")
         assert(lfs.chdir(current_dir))
         assert.same({}, result.syntax_errors)
         local pretty_result_string = tl.pretty_print_ast(result.ast)
         util.assert_line_by_line(expected_lua_code, pretty_result_string)
      end)
   end)
end)
