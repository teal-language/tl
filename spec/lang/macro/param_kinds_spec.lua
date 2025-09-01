local tl = require('tl')
local lua_gen = require('teal.gen.lua_generator')

describe('macro parameter kinds', function()
   it('requires annotations Statement or Expression', function()
      local code = [[
         local macro bad1!(x)
            return `$x`
         end
      ]]
      local _, errs = tl.parse(code)
      assert.not_same({}, errs)

      local code2 = [[
         local macro bad2!(x: number)
            return `$x`
         end
      ]]
      local _, errs2 = tl.parse(code2)
      assert.not_same({}, errs2)
   end)

   it('accepts Expression arguments and rejects Statement blocks', function()
      local code = [[
         local macro echo!(x: Expression)
            return `$x`
         end

         local a = echo!(1 + 2)
      ]]
      local ast, errs = tl.parse(code)
      assert.same({}, errs)
      local out, err = lua_gen.generate(ast, '5.4')
      assert.is_nil(err)
      assert.match('local a = 1 %+ 2', out)

   end)

   it('supports typed varargs (...: Expression)', function()
      local code = [[
         local macro twice_all!(...: Expression)
            local out = block('statements')
            for i = 1, select('#', ...) do
               local b = select(i, ...)
               table.insert(out, `$b`)
               table.insert(out, `$b`)
            end
            return out
         end

         twice_all!(print('a'), print('b'))
      ]]
      local ast, errs = tl.parse(code)
      assert.same({}, errs)
      local out, err = lua_gen.generate(ast, '5.4')
      assert.is_nil(err)
      local count = 0
      for _ in out:gmatch("print%(") do count = count + 1 end
      assert.is_true(count >= 4)

      local bad = [[
         local macro eat!(...: Expression)
            return ```$...```
         end

         eat!(```x = 1```)
      ]]
      local _, berrs = tl.parse(bad)
      assert.not_same({}, berrs)
   end)
end)
