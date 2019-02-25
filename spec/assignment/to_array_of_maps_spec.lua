local tl = require("tl")

describe("assignment to array of maps", function()
   it("resolves records to maps", function()
      local tokens = tl.lex([[
         local a: {{string:number}} = {
            {
               hello = 123,
               world = 234,
            },
            {
               foo = 345,
               bar = 456,
            },
         }
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
end)
