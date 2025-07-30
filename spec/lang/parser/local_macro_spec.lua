local tl = require('tl')

describe("local macro parsing", function()
   it("parses local macro", function()
      local ast, errs = tl.parse([[
         local macro foo!(): number
            return 1
         end
      ]])
      assert.same({}, errs)
      assert.same('local_macro', ast[1].kind)
   end)

   it("parses quotes and macro vars", function()
      local ast, errs = tl.parse([[
         local macro bar!(v: Block): Block
            return `local $v = 1`
         end
      ]])
      assert.same({}, errs)
      local quote = ast[1].body[1].exps[1]
      assert.same('macro_quote', quote.kind)
  end)

   it("rejects macro vars outside quotes", function()
      local _, errs = tl.parse([[
         local macro baz!(v: Block): Block
            return $v
         end
      ]])
      assert.not_same({}, errs)
   end)

   it("handles multiple statements inside quotes", function()
      local ast, errs = tl.parse([[
         local macro qux!(a: Block, b: Block): Block
            return `local $a = 1; local $b = 2`
         end
      ]])
      assert.same({}, errs)
      local quote = ast[1].body[1].exps[1]
      assert.same('macro_quote', quote.kind)
  end)
end)
