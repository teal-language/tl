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
         local macro twice!(x: Expression)
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
         local macro inc!(x: Expression)
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
         local macro inc!(x: Expression)
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

describe('statement macro invocation (paren form)', function()
   it('accepts bare record declaration as Statement argument', function()
      local code = [[
         local macro class!(b: Statement)
            return b
         end

         class!(record MyClass
            name: string
         end)

         local x: MyClass = { name = "ok" }
      ]]
      local ast, errs = tl.parse(code)
      assert.same({}, errs)
      local out, err = lua_gen.generate(ast, '5.4')
      assert.is_nil(err)
      
      out = out:gsub("%s+", " ")
      assert.match('local x = %s*%{ %s*name = "ok" %s*%}', out)
   end)

   it('duplicates a single Statement without backticks', function()
      local code = [[
         local macro twice!(b: Statement)
            local out = block('statements')
            table.insert(out, b)
            table.insert(out, b)
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

   it('still supports triple backtick Statement arguments', function()
      local code = [[
         local macro s!(b: Statement)
            return b
         end

         s!```
            do
               local q = 1
            end
         ```
      ]]
      local ast, errs = tl.parse(code)
      assert.same({}, errs)
      local out, err = lua_gen.generate(ast, '5.4')
      
      assert.is_nil(err)
   end)

   it('supports vararg Statement arguments (seq!)', function()
      local code = [[
         local macro seq!(...: Statement)
            local out = block('statements')
            for i = 1, select('#', ...) do
               local b = select(i, ...)
               table.insert(out, b)
            end
            return out
         end

         seq!(print('a'), print('b'))
      ]]
      local ast, errs = tl.parse(code)
      assert.same({}, errs)
      local out, err = lua_gen.generate(ast, '5.4')
      assert.is_nil(err)
      out = out:gsub("^%s+", "")
      assert.match("print%('a'%)%s*;%s*print%('b'%)", out)
   end)

   it('preserves record fields in macro-quoted type returned from macro', function()
      local code = [[
         local macro make_type!()
            return ```
               local type Rec = record
                  name: string
               end
            ```
         end

         make_type!()
         local x: Rec = { name = "ok" }
      ]]
      local ast, errs = tl.parse(code)
      assert.same({}, errs)
      local out, err = lua_gen.generate(ast, '5.4')
      assert.is_nil(err)
      out = out:gsub("%s+", " ")
      assert.match('local x = %s*%{ %s*name = "ok" %s*%}', out)
   end)

   it('allows macro LHS name via macro variable in declaration', function()
      local code = [[
         local macro def0!(name: Expression)
            return ```
               local $name = 0
            ```
         end

         def0!(zero)
         print(zero)
      ]]
      local ast, errs = tl.parse(code)
      assert.same({}, errs)
      local out, err = lua_gen.generate(ast, '5.4')
      assert.is_nil(err)
      out = out:gsub("%s+", " ")
      assert.match("local zero = 0", out)
      assert.match("print%(%s*zero%s*%)", out)
   end)
end)
