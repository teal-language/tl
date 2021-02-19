local util = require("spec.util")

describe("ipairs", function()
   it("should report when a tuple can't be converted to an array (literal)", util.check_type_error([[
      for i, v in ipairs({{1}, {"a"}}) do
      end
   ]], {
      { msg = [[expected an array: at index 2: got {string "a"}, expected {number}]] },
   }))

   it("should report when a tuple can't be converted to an array (variable)", util.check_type_error([[
      local my_tuple = {{1}, {"a"}}
      for i, v in ipairs(my_tuple) do
      end
   ]], {
      { msg = [[attempting ipairs loop on tuple that's not a valid array: ({{number}, {string "a"}})]] },
      { msg = [[argument 1: unable to convert tuple {{number}, {string "a"}} to array]] },
   }))
end)
