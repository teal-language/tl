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

   it("rejects macro vars outside quotes", function()
      local _, errs = tl.parse([[
         local macro baz!(v: Block): Block
            return $v
         end
      ]])
      assert.not_same({}, errs)
   end)

   it("quotes a simple statement into a constructor", function()
      local ast, errs = tl.parse([[
         local macro bar!(): Block
            return `x = 1`
         end
      ]])
      assert.same({}, errs)
      local quote = ast[1].body[1].exps[1]
      local lua, err = tl.generate(quote, "5.4")
      assert.is_nil(err)
      assert.same('{ kind = "assignment", tk = "=", [1] = { kind = "variable", tk = "x" }, [2] = { kind = "expression_list", [1] = { kind = "integer", tk = "1" } } }', lua)
   end)
end)
