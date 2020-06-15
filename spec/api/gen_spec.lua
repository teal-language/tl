local tl = require("tl")
local util = require("spec.util")

describe("tl.gen", function()
   it("can process tl strings", function()
      local input = [[
         local movie:string = "Star Wars: Episode"
         local episode: number = 4
      ]]

      local expected_output = [[
         local movie = "Star Wars: Episode"
         local episode = 4
      ]]

      local output = tl.gen(input)
      util.assert_line_by_line(expected_output, output)
   end)

   it("returns result on type errors", function()
      local input = [[
         local movie:string = 1
      ]]

      local output, result = tl.gen(input)

      assert.equal('local movie = 1', output)
      assert.match("expected string", result.type_errors[1].msg, 1, true)
      assert.is_nil(err)
   end)

   it("returns error on syntax errors", function()
      local input = [[
         local movie:string =
      ]]

      local output, result = tl.gen(input)

      assert.is_nil(output)
      assert.same({}, result.type_errors)
      assert.is_not_nil(result.syntax_errors)
   end)
end)
