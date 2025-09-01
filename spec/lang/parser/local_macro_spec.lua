local tl = require('tl')
local lua_gen = require('teal.gen.lua_generator')

describe("local macro parsing", function()
   it("removes local macros after read-time expansion", function()
      local ast, errs = tl.parse([[
         local macro foo!(): number
            return 1
         end
      ]])
      assert.same({}, errs)
      
      assert.is_nil(ast[1])
   end)

   it("rejects macro vars outside quotes", function()
      local _, errs = tl.parse([[
         local macro baz!(v: Block): Block
            return $v
         end
      ]])
      assert.not_same({}, errs)
   end)

   it("expands triple backtick quotes into concrete statements", function()
      local ast, errs = tl.parse([[
         local macro bar!(): Block
            return ```x = 1```
         end

         bar!()
      ]])
      assert.same({}, errs)
      local lua, err = lua_gen.generate(ast, "5.4")
      assert.is_nil(err)
      assert.match('x%s*=%s*1', lua)
   end)

   it("splices variables inside triple backticks", function()
      local ast, errs = tl.parse([[
         local macro bar!(x: Expression): Block
            return ```y = $x```
         end

         bar!(1)
      ]])
      assert.same({}, errs)
      local lua, err = lua_gen.generate(ast, "5.4")
      assert.is_nil(err)
      assert.match('y%s*=%s*1', lua)
   end)

   it("rejects nested macro invocation", function()
      local _, errs = tl.parse([[
         local macro inner!(x: Block): Block
            return x
         end

         local macro outer!(x: Block): Block
            return inner!(x)
         end
      ]])
      assert.not_same({}, errs)
   end)

   it("rejects empty macro quotes", function()
      local _, errs = tl.parse([[
         local macro foo!(): Block
            return ``
         end
      ]])
      assert.not_same({}, errs)
   end)

   it("rejects whitespace-only macro quotes", function()
      local _, errs = tl.parse([[
         local macro foo!(): Block
            return `   \n\t  `
         end
      ]])
      assert.not_same({}, errs)
   end)

   describe("triple backtick macro quotes", function()
      it("expands all statements inside triple quotes", function()
         local ast, errs = tl.parse([[
            local macro foo!(): Block
               return ```
                  local x = 1
                  y = 2
               ```
            end

            foo!()
         ]])
         assert.same({}, errs)
         local lua, err = lua_gen.generate(ast, "5.4")
         assert.is_nil(err)
         assert.match('local x%s*=%s*1', lua)
         assert.match('y%s*=%s*2', lua)
      end)

      it("rejects whitespace-only triple quotes", function()
         local _, errs = tl.parse([[
            local macro foo!(): Block
               return ```   
               ```
            end
         ]])
         assert.not_same({}, errs)
      end)

      it("reports unterminated triple quotes", function()
         local _, errs = tl.parse([[
            local macro foo!(): Block
               return ```x = 1`
            end
         ]])
         assert.not_same({}, errs)
      end)

      it("captures both statements inside triple quotes", function()
         local ast, errs = tl.parse([[
            local macro foo!(): Block
               return ```
                  y = 1
                  y = 2
               ```
            end

            foo!()
         ]])
         assert.same({}, errs)
         local lua, err = lua_gen.generate(ast, "5.4")
         assert.is_nil(err)
         assert.match('y%s*=%s*1', lua)
         assert.match('y%s*=%s*2', lua)
      end)
   end)
end)
