local tl = require("tl")
local util = require("spec.util")

describe("assert", function()
   it("unwraps a specifically T|nil value into a T value", function()
      util.mock_io(finally, {
         ["assert.tl"] = [[
            local function test(x: string): string
               return x
            end

            local x: string|nil = "hello"

            test(assert(x))
         ]]
      })
      local result, err = tl.process("assert.tl")

      assert.same({}, result.syntax_errors)
      assert.same({}, result.type_errors)
      assert.same({}, result.unknowns)
   end)
end)
