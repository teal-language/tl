local util = require("spec.util")

describe("flow analysis with is", function()
   it("does not crash on inexistent variables (regression test for #409)", util.check_type_error([[
      local function f(a: b, c: string): boolean
          if x == nil or #x == 0 then
              return false
          end
      end
   ]], {
      { y = 1, msg = "unknown type b"},
      { y = 2, msg = "unknown variable: x"},
      { y = 2, msg = "cannot resolve a type for x here"},
   }))

   describe("on expressions", function()
      it("narrows type on expressions with and", util.check([[
         local x: number | string

         local s = x is string and x:lower()
      ]]))

      it("does not narrow type on expressions with conditional 'is' and or", util.check_type_error([[
         local x: number | string

         local r = x is string and (x:sub(1,1) == "a") or (x:upper() == "k")
      ]], {
         { x = 62, msg = "cannot index key 'upper' in union 'x' of type number | string"}
      }))

      it("does not narrow type on expressions with conditional 'is' and or", util.check([[
         local x: number | string

         x = "b"
         local s = x is string and (x:sub(1,1) == "a" and x) or "somethingelse"
         print(s:upper())
      ]]))

      it("narrows type on expressions with not", util.check([[
         local x: number | string

         local function ohoh(n: number): number
            if n > 10 then
               return n
            else
               return nil
            end
         end

         local s = not x is string and ohoh(x + 1)
      ]]))

      it("does not narrow 'or' type on conditional expressions with not", util.check_type_error([[
         local x: number | string

         local function ohoh(n: number): number
            if n > 10 then
               return n
            else
               return nil
            end
         end

         local s = not x is string and ohoh(x + 1) or x:upper() -- x <= 10 may fall into x:upper()
      ]], {
         { y = 11, x = 57, msg = [[cannot index key 'upper' in union 'x' of type number | string]]}
      }))

      it("propagates with 'and' and 'assert' because result is known to be truthy", util.check([[
         local record Foo
         end
         local makeFoo: function(string): Foo
         local a: string | Foo
         local _b: Foo = a is string and assert(makeFoo(a)) or a
      ]]))

      it("does not propagate with 'and' and arbitrary functions because result may be nil", util.check_type_error([[
         local record Foo
         end
         local makeFoo: function(string): Foo
         local a: string | Foo
         local _b: Foo = a is string and makeFoo(a) or a
      ]], {
         { msg = "got string | Foo, expected Foo" },
      }))
   end)

   describe("on if", function()
      it("resolves both then and else branches", util.check([[
         local t: number | string
         if t is number then
            print(t + 1)
         else
            print(t:upper())
         end
      ]]))

      it("works for type arguments", util.check([[
         local function test<T>(t: T)
            if t is number then
               print(t + 1)
            else
               print(t)
            end
         end
      ]]))

      it("not works for type arguments", util.check([[
         local function test<T>(t: T)
            if not t is number then
               print(t)
            else
               print(t + 1)
            end
         end
      ]]))

      it("negates with not", util.check([[
         local t: number | string
         if not t is number then
            print(t:upper())
         else
            print(t + 1)
         end
      ]]))

      it("resolves with elseif", util.check([[
         local v: number | string | {boolean}
         if v is number then
            v = v + 1
         elseif v is string then
            print(v:upper())
         end
      ]]))

      it("resolves with else and a type definition (regression test for #250)", util.check([[
         local type A = number
         local type B = record
           h: UnionAorB
           t: UnionAorB
         end
         local type UnionAorB = A | B

         local function head(n: UnionAorB): UnionAorB
           if n is B then
             return n.h
           else
             return n + 1
           end
         end
      ]]))

      it("resolves incrementally with elseif", util.check([[
         local v: number | string | {boolean}
         if v is number then
            v = v + 1
         elseif v is string then
            print(v:upper())
         else
            local b: {boolean} = v
         end
      ]]))

      it("can use inferred facts in elseif expression", util.check([[
         local record Rec
            op: string
         end
         local v: string | Rec
         if v is string then
            v = v:upper()
         elseif v.op:match("something") then
            print(v.op:upper())
         end
      ]]))

      it("resolves partially", util.check_type_error([[
         local v: number | string | {boolean}
         if v is number then
            print(v + 1)
         else
            print(v:upper()) -- v is string | {boolean}
         end
      ]], {
         { msg = [[cannot index key 'upper' in union 'v' of type string | {boolean} (inferred at foo.tl:4:10)]] }
      }))

      it("builds union types with is and or", util.check_type_error([[
         local v: number | boolean | {string}
         if (v is number) or (v is boolean) then
            print(v + 1) -- ERR
         else
            for _, s in ipairs(v) do
               print(s:upper())
            end
         end
      ]], {
         { msg = "cannot use operator '+' for types number | boolean" },
      }))

      it("builds union types with is and or (parses priorities correctly)", util.check_type_error([[
         local v: number | boolean | {string}
         if v is number or v is boolean then
            print(v + 1) -- ERR
         else
            for _, s in ipairs(v) do
               print(s:upper())
            end
         end
      ]], {
         { msg = "cannot use operator '+' for types number | boolean" },
      }))

      it("resolves incrementally with elseif and negation", util.check([[
         local v: number | string | {boolean}
         if v is number then
            print(v + 1)
         elseif not v is {boolean} then
            print(v:upper())
         else
            v = {true, false}
         end
      ]]))

      it("rejects other side of the union in the tested branch", util.check_type_error([[
         local t: number | string
         if t is number then
            print(t:upper())
         else
            print(t + 1)
         end
      ]], {
         { y = 3, msg = [[cannot index key 'upper' in number 't' of type number (inferred at foo.tl:2:15)]] },
         { y = 5, msg = [[cannot use operator '+' for types string (inferred at foo.tl:4:10) and integer]] },
      }))

      -- this is not an empty union because `number | string` implies nil.
      pending("detects empty unions", util.check_type_error([[
         local t: number | string
         if t is number then
            t = t + 1
         elseif t is string then
            print(t:upper())
         else
            print(t)
         end
      ]], {
         { y = 6, msg = 'cannot resolve a type for t here' },
      }))

      it("is combined with other tests narrows it, but prevents its negation from narrowing types (any)", util.check([[
         local function func(x: string, y: string): string
            return x > y and x .. "!" or x
         end

         local function f(d: any): any
            if d is string and func(d, "a") then
               local d = func(d, d)
            elseif d is string and func(d, "b") then
               return d .. "???"
            else
               return d -- d is still any here
            end
         end
      ]]))

      it("is combined with other tests narrows it, but prevents its negation from narrowing types (union)", util.check([[
         local function func(x: string, y: string): string
            return x > y and x .. "!" or x
         end

         local function f(d: any): any
            local d = d as (number | string | function)
            if d is string and func(d, "a") then
               local d = func(d, d)
            elseif d is string and func(d, "b") then
               return d .. "???"
            else
               return d
            end
         end
      ]]))

      it("else narrows the negation of 'or' if both of its sides match 'is' purely", util.check_type_error([[
         local a: string | number
         local b: boolean | number | thread
         local c: number

         if (a is string and b is boolean) or b is thread then
            local isb: boolean = b
         else
            local isb: boolean = b
         end
      ]], {
         { y = 6, msg = "got boolean | thread (inferred at" },
         { y = 8, msg = "got boolean | number, expected" },
      }))

      it("else narrows the negation of the pure side of 'or'", util.check_type_error([[
         local a: string | number
         local b: boolean | number | thread
         local c: number

         if (a == 9 and b is boolean) or b is thread then
            local isb: boolean = b
         else
            local isb: boolean = b
         end
      ]], {
         { y = 6, msg = "got boolean | thread (inferred at" },
         { y = 8, msg = "got boolean | number, " },
      }))

      it("else narrows the negation of the pure side of 'or' (reverse)", util.check_type_error([[
         local a: string | number
         local b: boolean | number | thread
         local c: number

         if b is thread or (a == 9 and b is boolean) then
            local isb: boolean = b
         else
            local isb: boolean = b
         end
      ]], {
         { y = 6, msg = "got thread | boolean (inferred at" },
         { y = 8, msg = "got boolean | number (inferred at" },
      }))

      it("else narrows the negation of the pure side of 'or' (reverse)", util.check_type_error([[
         local a: string | number
         local b: boolean | number | thread
         local c: number

         if b is thread or (b is boolean and a == 9) then
            local isb: boolean = b
         else
            local isb: boolean = b
         end
      ]], {
         { y = 6, msg = "got thread | boolean (inferred at" },
         { y = 8, msg = "got boolean | number (inferred at" },
      }))

      it("else narrows the negation of 'or' if both of its sides match 'is' unconditionally", util.check_type_error([[
         local a: string | number
         local b: boolean | thread
         local c: number

         if (a is string and a == "hello" and (b is boolean and c == 2)) and c > 0 then
            print(a:upper())
            local isb: boolean = b
         else
            print(a:upper())
            local isb: boolean = b
         end
      ]], {
         { y = 9, msg = "cannot index key 'upper' in union 'a' of type string | number" },
         { y = 10, msg = "got boolean | thread, expected boolean" },
      }))


      it("does not crash on invalid variables", util.check_type_error([[
         local t: number | string
         if x is number then
            print("foo")
         else
            print("hello")
         end
      ]], {
         { y = 2, x = 13, msg = "unknown variable: x" },
         { y = 2, x = 15, msg = "cannot resolve a type for x here" },
         { y = 4, x = 10, msg = "cannot resolve a type for x here" },
      }))

      it("can resolve on else block even if it can't on if block (#210)", util.check([[
         local function foo(v: any)
            if not v is string then
               print("foo")
            else
               print(v:upper())
            end
         end
      ]]))

      it("attempting to use a type as a value produces sensible messages (#210)", util.check_type_error([[
         local record MyRecord
           my_record_field: number
         end
         local type a = string | number | MyRecord

         if a is string then
            print("Hello, " .. a)
         elseif a is number then      --  8
            print(a + 10)
         else
            print(a.my_record_field)  --  11
         end
      ]], {
         { msg = "can only use 'is' on variables, not types" },
         { msg = "cannot use operator '..'" },
         { msg = "can only use 'is' on variables, not types" },
         { msg = "cannot use operator '+'" },
         { msg = "cannot index" },
      }))

      it("produces no errors or warnings for checks on unions of records", util.check_warnings([[
         local record R1
            metamethod __is: function(self: R1|R2): boolean = macroexp(_self: R1|R2): boolean
               return true
            end
         end

         local record R2
            metamethod __is: function(self: R1|R2): boolean = macroexp(_self: R1|R2): boolean
               return false
            end
         end

         local type RS = R1 | R2

         local rs1 : RS

         if rs1 is R1 then
            print("yes")
         end

         local rs2 : R1 | R2

         if rs2 is R2 then
            print("yes")
         end
      ]], {}, {}))

      it("gen cleaner checking codes for nil", util.gen([[
         local record R
            f: function()
         end
         local function get(): R | nil
         end
         local r = get()
         if not r is nil then
            r.f()
         end
      ]], [[



local function get()
end
local r = get()
if not (r == nil) then
   r.f()
end]]))

   end)

   describe("on while", function()
      pending("needs to resolve a fixpoint to accept some valid code", util.check([[
         local t: number | string
         t = 1
         if t is number then
            while t < 1000 do
               t = t + 1
               if t == 10 then
                  t = "hello"
               end
               if t is string then
                  t = 20
               end
            end
         end
      ]]))

      it("widens narrowed union if value is assigned", util.check_type_error([[
         local t: number | string
         t = 1
         if t is number then
            while t < 1000 do
               if t is number then
                  t = t + 1
               end
               if t == 10 then
                  t = "hello"
               end
            end
         end
      ]], {
         { y = 4, msg = [[cannot use operator '<' for types number | string and integer]] },
      }))

      it("preserves narrowed union in loop if value is not assigned", util.check([[
         local function f(s: string, fn: function())
            print(s)
            fn()
         end

         local function handle_writer(pipe: FILE, x: {string} | string)
            if x is {string} then
               repeat
                  for i, v in ipairs(x) do
                     pipe:write(v)

                     -- this #x produces no error even though it's inside a loop
                     if i ~= #x then
                        pipe:write("\n")
                     else
                        f("\n", function()
                           print(pipe)
                        end)
                     end
                  end
               until false
            elseif x then
               f(x, function()
                  print(pipe)
               end)
            end
         end
      ]]))

      it("resolves is on the test", util.check([[
         local function process(ts: {number | string})
            local t: number | string
            t = ts[1]
            local i = 1
            while t is number do
               print(t + 1)
               i = i + 1
               t = ts[i]
            end
         end
      ]]))
   end)

   describe("code gen", function()
      describe("limitations", function()
         it("cannot discriminate a union between multiple table types", util.check_type_error([[
            local t: {number} | {string}
            if t is {number} then
               print(t)
            end
         ]], {
            { y = 1, msg = [[cannot discriminate a union between multiple table types: {number} | {string}]] },
         }))

         it("cannot discriminate a union between records", util.check_type_error([[
            local type R1 = record
               foo: string
            end
            local type R2 = record
               foo: string
            end
            local t: R1 | R2
         ]], {
            { y = 7, msg = [[cannot discriminate a union between multiple table types: R1 | R2]] },
         }))

         it("cannot discriminate a union between multiple string/enum types", util.check_type_error([[
            local type Enum = enum
               "hello"
               "world"
            end
            local t: string | Enum
         ]], {
            { y = 5, msg = [[cannot discriminate a union between multiple string/enum types: string | Enum]] },
         }))

         it("literal strings are truthy, preserve 'is' inference", util.check([[
            local x: number | string

            local s = x is string and "literal" or tostring(x / 2)
         ]]))

         it("literal numbers are truthy, preserve 'is' inference", util.check([[
            local x: number | string

            local n = x is number and 123 or tonumber(x:sub(1,2))
         ]]))

         it("literal tables are truthy, preserve 'is' inference", util.check([[
            local x: number | string

            local record R
               z: number
            end

            local r: R = x is number and { z = 123.0 } or { z = tonumber(x:sub(1,2)) }
         ]]))

         it("relational operators do not preserve 'is' inference", util.check_type_error([[
            local x: number | string

            local n = x is number and x < 123 or tonumber(x:sub(1,2))
         ]], {
            { msg = "cannot use operator 'or' for types boolean and number" },
            { y = 3, x = 61, msg = "cannot index key 'sub' in union 'x' of type number | string" },
         }))
      end)

      it("generates type checks for primitive types", util.gen([[
         local function process(ts: {number | string | boolean})
            local t: number | string | boolean
            t = ts[1]
            if t is number then
               print(t + 1)
            elseif t is string or t is boolean then
               print(t)
            end
         end
      ]], [[
         local function process(ts)
            local t
            t = ts[1]
            if type(t) == "number" then
               print(t + 1)
            elseif type(t) == "string" or type(t) == "boolean" then
               print(t)
            end
         end
      ]]))

      it("generates type checks for non-primitive types", util.gen([[
         local type U = record
            userdata
         end
         global function process(ts: {number | {string} | boolean | U})
            local t: number | {string} | boolean | U
            t = ts[1]
            if t is number then
               print(t + 1)
            elseif t is {string} or t is boolean then
               print(t)
            elseif t is U then
               print(t)
            end
         end
      ]], [[



         function process(ts)
            local t
            t = ts[1]
            if type(t) == "number" then
               print(t + 1)
            elseif type(t) == "table" or type(t) == "boolean" then
               print(t)
            elseif type(t) == "userdata" then
               print(t)
            end
         end
      ]]))
   end)

end)
