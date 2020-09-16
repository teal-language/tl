local tl = require("tl")
local util = require("spec.util")

describe("Uncaught compiler errors", function()
   local old_parse_program
   setup(function()
      old_parse_program = tl.parse_program
      tl.parse_program = function(tokens, _, chunkname)
         return old_parse_program(tokens, {}, chunkname)
      end
   end)
   teardown(function()
      tl.parse_program = old_parse_program
   end)
   it("should be reported when loading modules", function()
      util.run_mock_project(finally, {
         dir_name = "uncaught_compiler_error_test",
         dir_structure = {
            ["my_module.tl"] = [[todo, write module :)]],
            ["my_script.tl"] = [[local mod = require("my_module"); mod.do_things()]],
         },
         cmd = "run",
         args = "my_script.tl",
         generated_files = {},
         popen = {
            status = nil,
            exit = "exit",
            code = 1,
         },
      })
   end)
end)
