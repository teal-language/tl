local tl = require('tl')

describe("macro invocation parsing", function()
   it("parses macro invocation", function()
      local ast, errs = tl.parse([[
         local macro my_macro!(x: Block)
            assert(x.kind == "string")
         end

         my_macro!("hello")
      ]])
      assert.same({}, errs)
      local call = ast[2]
      assert.same('macro_invocation', call.kind)
      assert.same('my_macro', call.e1.tk)
      assert.same('hello', call.args[1].conststr)
   end)
end)
