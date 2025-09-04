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

   it('handles commas inside Statement followed by another arg', function()
      local code = [[
         local macro wrap!(s: Statement, e: Expression)
            local out = block('statements')
            table.insert(out, s)
            table.insert(out, `print($e)`)
            return out
         end

         local t = {1,2,3}
         wrap!(
            for _, x in ipairs(t) do
               print(x)
            end
         , 'ok')
      ]]
      local ast, errs = tl.parse(code)
      assert.same({}, errs)
      local out, err = lua_gen.generate(ast, '5.4')
      assert.is_nil(err)
      out = out:gsub('%s+', ' ')
      assert.match('for _, x in ipairs%(%s*t%s*%) do%s*print%(x%)%s*end', out)
      assert.match("print%('ok'%)", out)
   end)

   it('handles commas in first Statement when two Statement args', function()
      local code = [[
         local macro both!(a: Statement, b: Statement)
            local out = block('statements')
            table.insert(out, a)
            table.insert(out, b)
            return out
         end

         both!(
            for _, v in ipairs({1,2}) do
               print(v)
            end,
            print('second')
         )
      ]]
      local ast, errs = tl.parse(code)
      assert.same({}, errs)
      local out, err = lua_gen.generate(ast, '5.4')
      assert.is_nil(err)
      out = out:gsub('%s+', ' ')
      assert.match('for _, v in ipairs%(%{ 1, 2 %}%).*end', out)
      assert.match("print%('second'%)", out)
   end)

   it('requires do-end wrapper for top-level commas in local declarations', function()
      local code = [[
         local macro wrap!(s: Statement, e: Expression)
            local out = block('statements')
            table.insert(out, s)
            table.insert(out, `print($e)`)
            return out
         end

         wrap!(
            local a, b = 1, 2
         , 'ok')
      ]]
      local ast, errs = tl.parse(code)
      assert.truthy(#errs > 0)
      assert.match("wrap the statement in 'do ... end'", errs[1].msg)
   end)

   it('accepts local declarations with comma when wrapped in do-end', function()
      local code = [[
         local macro wrap!(s: Statement, e: Expression)
            local out = block('statements')
            table.insert(out, s)
            table.insert(out, `print($e)`)
            return out
         end

         wrap!(
            do
               local a, b = 1, 2
            end,
            'ok')
      ]]
      local ast, errs = tl.parse(code)
      assert.same({}, errs)
      local out, err = lua_gen.generate(ast, '5.4')
      assert.is_nil(err)
      out = out:gsub('%s+', ' ')
      assert.match("print%('ok'%)", out)
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


   it('accepts if/then Statement containing commas', function()
      local code = [[
         local macro wrap!(s: Statement, e: Expression)
            local out = block('statements')
            table.insert(out, s)
            table.insert(out, `print($e)`)
            return out
         end

         wrap!(
            if true then
               print('x', 'y')
            end,
            'ok')
      ]]
      local ast, errs = tl.parse(code)
      assert.same({}, errs)
      local out, err = lua_gen.generate(ast, '5.4')
      assert.is_nil(err)
      out = out:gsub('%s+', ' ')
      assert.match("if true then%s*print%('x', 'y'%)%s*end", out)
      assert.match("print%('ok'%)", out)
   end)

   it("requires do-end for 'local a = 1, 2' in Statement arg", function()
      local code = [[
         local macro wrap!(s: Statement, e: Expression)
            local out = block('statements')
            table.insert(out, s)
            table.insert(out, `print($e)`)
            return out
         end

         wrap!(
            local a = 1, 2
         , 'ok')
      ]]
      local _, errs = tl.parse(code)
      assert.truthy(#errs > 0)
      assert.match("wrap the statement in 'do ... end'", errs[1].msg)
   end)

   it("requires do-end for 'local a, b = 1' in Statement arg", function()
      local code = [[
         local macro wrap!(s: Statement, e: Expression)
            local out = block('statements')
            table.insert(out, s)
            table.insert(out, `print($e)`)
            return out
         end

         wrap!(
            local a, b = 1
         , 'ok')
      ]]
      local _, errs = tl.parse(code)
      assert.truthy(#errs > 0)
      assert.match("wrap the statement in 'do ... end'", errs[1].msg)
   end)

   it("requires do-end for typed multi-var local decl in Statement arg", function()
      local code = [[
         local macro wrap!(s: Statement, e: Expression)
            local out = block('statements')
            table.insert(out, s)
            table.insert(out, `print($e)`)
            return out
         end

         wrap!(
            local a, b: integer
         , 'ok')
      ]]
      local _, errs = tl.parse(code)
      assert.truthy(#errs > 0)
      assert.match("wrap the statement in 'do ... end'", errs[1].msg)
   end)

   it('accepts typed single-var local decl without do-end', function()
      local code = [[
         local macro wrap!(s: Statement, e: Expression)
            local out = block('statements')
            table.insert(out, s)
            table.insert(out, `print($e)`)
            return out
         end

         wrap!(
            local a: integer
         , 'ok')
      ]]
      local ast, errs = tl.parse(code)
      assert.same({}, errs)
      local out, err = lua_gen.generate(ast, '5.4')
      assert.is_nil(err)
      out = out:gsub('%s+', ' ')
      assert.match("print%('ok'%)", out)
   end)

   it('does not require do-end when comma appears inside nested local decl', function()
      local code = [[
         local macro wrap!(s: Statement, e: Expression)
            local out = block('statements')
            table.insert(out, s)
            table.insert(out, `print($e)`)
            return out
         end

         wrap!(
            if true then
               local a, b = 1, 2
            end,
            'ok')
      ]]
      local ast, errs = tl.parse(code)
      assert.same({}, errs)
      local out, err = lua_gen.generate(ast, '5.4')
      assert.is_nil(err)
      out = out:gsub('%s+', ' ')
      assert.match("if true then%s*local a, b = 1, 2%s*end", out)
      assert.match("print%('ok'%)", out)
   end)

   it('vararg Statement args accept statements with commas', function()
      local code = [[
         local macro seq!(...: Statement)
            local out = block('statements')
            for i = 1, select('#', ...) do
               local b = select(i, ...)
               table.insert(out, b)
            end
            return out
         end

         seq!(
            for _, v in ipairs({1,2}) do print(v) end,
            a, b = 1, 2
         )
      ]]
      local ast, errs = tl.parse(code)
      assert.same({}, errs)
      local out, err = lua_gen.generate(ast, '5.4')
      assert.is_nil(err)
      out = out:gsub('%s+', ' ')
      assert.match('for _, v in ipairs%(%{ 1, 2 %}%).-end', out)
      assert.match('a, b = 1, 2', out)
   end)

   it('accepts for-in Statement with commas followed by table literal expression', function()
      local code = [[
         local macro mac!(st: Statement, expr: Expression)
            local out = block('statements')
            table.insert(out, st)
            table.insert(out, `print($expr)`)
            return out
         end

         local t = { 1, 2, 3, 4 }
         mac!(for i, v in ipairs(t) do print(i, v) end, { t, t, t })
      ]]
      local ast, errs = tl.parse(code)
      assert.same({}, errs)
      local out, err = lua_gen.generate(ast, '5.4')
      assert.is_nil(err)
      out = out:gsub('%s+', ' ')
      assert.match('for i, v in ipairs%(%s*t%s*%) do%s*print%(i, v%)%s*end', out)
      assert.match('print%(%s*%{ %s*t, %s*t, %s*t %}%s*%)', out)
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
