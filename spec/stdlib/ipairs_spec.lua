local util = require("spec.util")

describe("ipairs", function()
   it("should report when a tuple can't be converted to an array", util.check_type_error([[
      for i, v in ipairs({{1}, {"a"}}) do
      end
   ]], {
      { msg = [[attempting ipairs loop on tuple that's not a valid array: ({1: {number}, 2: {string "a"}})]] },
      { msg = [[argument 1: unable to convert tuple {1: {number}, 2: {string "a"}} to array]] },
   }))
end)
