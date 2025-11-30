local tl = require('tl')
local lua_gen = require('teal.gen.lua_generator')
local util = require('spec.util')

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
      assert.same("print('hi'); print('hi')", out)
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
      out = out:gsub("^%s+", ""):gsub("%s+$", "")
      assert.same('local y = 2 + 1', out)
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
      out = out:gsub("^%s+", ""):gsub("%s+$", "")
      assert.same('local y = 2 + 1 + 1', out)
   end)

   it('expands macro invocations inside else blocks', function()
      local code = [[
         local macro one!()
            return `1`
         end

         local x = 0
         if false then
            x = 0
         else
            x = one!()
         end
      ]]

      local ast, errs = tl.parse(code)
      assert.same({}, errs)
      local out, err = lua_gen.generate(ast, '5.4')
      assert.is_nil(err)
      out = out:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
      assert.same("local x = 0 if false then x = 0 else x = 1 end", out)
   end)
end)

describe('macro unknown type error', function()
   it('reports unknown type from macro-built nominal without crashing', util.check_type_error([[ 
      local macro badtype!()
         local blk = require("teal.block")
         local BI = blk.BLOCK_INDEXES

         local function mkident(s: string)
            local b = block('identifier')
            b.tk = s
            return b
         end

         -- Build: local type T = DoesNotExist
         local lt = block('local_type')
         lt[BI.LOCAL_TYPE.VAR] = mkident('T')

         local nt = block('nominal_type')
         nt[BI.NOMINAL_TYPE.NAME] = mkident('DoesNotExist')

         local td = block('typedecl')
         td[BI.TYPEDECL.TYPE] = nt

         local newt = block('newtype')
         newt[BI.NEWTYPE.TYPEDECL] = td

         lt[BI.LOCAL_TYPE.VALUE] = newt

         return lt
      end

      badtype!()
   ]], {
      { msg = 'unknown type DoesNotExist' },
   }))
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
      
      out = out:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
      assert.same('local MyClass = {} local x = { name = "ok" }', out)
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
      out = out:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
      assert.same("local t = { 1, 2, 3 } for _, x in ipairs(t) do print(x) end; print('ok')", out)
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
   out = out:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
      assert.same("for _, v in ipairs({ 1, 2 }) do print(v) end; print('second')", out)
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
      out = out:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
      assert.same("do local a, b = 1, 2 end; print('ok')", out)
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
      assert.same("print('hi'); print('hi')", out)
   end)

   it('rejects triple backtick Statement arguments outside macro definitions', function()
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
      local _, errs = tl.parse(code)
      assert.not_same({}, errs)
      local saw_macro_quote_error = false
      for _, err in ipairs(errs) do
         if err.msg:match('macro quotes can only be used inside macro statements') then
            saw_macro_quote_error = true
            break
         end
      end
      assert.is_true(saw_macro_quote_error)
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
      out = out:gsub("^%s+", ""):gsub("%s+$", "")
      assert.same("print('a'); print('b')", out)
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
      out = out:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
      assert.same("if true then print('x', 'y') end; print('ok')", out)
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
      out = out:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
      assert.same("local a; print('ok')", out)
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
      out = out:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
      assert.same("if true then local a, b = 1, 2 end; print('ok')", out)
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
   out = out:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
      assert.same('for _, v in ipairs({ 1, 2 }) do print(v) end; a, b = 1, 2', out)
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
      out = out:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
      assert.same('local t = { 1, 2, 3, 4 } for i, v in ipairs(t) do print(i, v) end; print({ t, t, t })', out)
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
      out = out:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
      assert.same('local Rec = {} local x = { name = "ok" }', out)
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
      out = out:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
      assert.same('local zero = 0 print(zero)', out)
   end)

   it('splices a nominal_type into type positions (regression)', util.check([[ 
      local macro cast_demo!()
         local blk = require("teal.block")
         local BI = blk.BLOCK_INDEXES
         local function nt_named(name: string)
            local nt = block('nominal_type')
            local id = block('identifier')
            id.tk = name
            nt[BI.NOMINAL_TYPE.NAME] = id
            return nt
         end
         local T = nt_named('Foo')
         return ```
            local type Foo = integer
            local _ = 1 as $T
         ```
      end

      cast_demo!()
   ]]))

   it('gives a proper error message on known block kind', function()
      local code = [[
         local macro make_weird!()
            local blk = require("teal.block")
            local BI = blk.BLOCK_INDEXES

            local weird = block('whatever')
            weird[BI.WHATEVER.SOME_FIELD] = 123

            return weird
         end

         make_weird!()
      ]]
      local _, errs = tl.parse(code)
      assert.truthy(#errs > 0)
      --error is ./teal/macro_eval.lua:108: unknown block kind: whatever
      --ignore file/line info
      assert.match("unknown block kind: whatever", errs[1].msg)
   end)
end)
