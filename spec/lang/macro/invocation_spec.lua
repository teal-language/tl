local tl = require('tl')
local lua_gen = require('teal.gen.lua_generator')

describe('macro invocation expansion', function()
   it('expands macro with no arguments', function()
      local code = [[
         local macro hello!()
            return `print("hi")`
         end

         hello!()
      ]]
      local ast, errs = tl.parse(code)
      assert.same({}, errs)
      local out, err = lua_gen.generate(ast, '5.4')
      assert.is_nil(err)
      out = out:gsub("^%s+", ""):gsub("%s+$", "")
      assert.same('print("hi")', out)
   end)

   it('expands macro with argument splicing', function()
      local code = [[
         local macro twice!(x)
            local out = block('statements')
            table.insert(out, `$x`)
            table.insert(out, `$x`)
            return out
         end

         twice!(print('hi'))
      ]]
      local ast, errs = tl.parse(code)
      assert.same({}, errs)
      local out, err = lua_gen.generate(ast, '5.4')
      assert.is_nil(err)
      out = out:gsub("^%s+", ""):gsub("%s+$", "")
      assert.match("print%('hi'%)%s*;%s*print%('hi'%)", out)
   end)

   it('expands macro used in expressions', function()
      local code = [[
         local macro inc!(x)
            return `$x + 1`
         end

         local y = inc!(2)
      ]]
      local ast, errs = tl.parse(code)
      assert.same({}, errs)
      local out, err = lua_gen.generate(ast, '5.4')
      assert.is_nil(err)
      out = out:gsub("^%s+", "")
      assert.match('local y = 2 %+ 1', out)
   end)

   it('expands nested macro invocations eagerly', function()
      local code = [[
         local macro inc!(x)
            return `$x + 1`
         end

         local y = inc!(inc!(2))
      ]]
      local ast, errs = tl.parse(code)
      assert.same({}, errs)
      local out, err = lua_gen.generate(ast, '5.4')
      assert.is_nil(err)
      out = out:gsub("^%s+", "")
      assert.match('local y = 2 %+ 1 %+ 1', out)
   end)
end)
