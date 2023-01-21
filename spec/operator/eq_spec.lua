local util = require("spec.util")

describe("==", function()
   it("passes with the same type", util.check([[
      local x = "hello"
      if x == "hello" then
         print("hello!")
      end
   ]]))

   it("fails with different types", util.check_type_error([[
      local x = "hello"
      if not x == "hello" then
         print("unreachable")
      end
   ]], {
      { msg = "not comparable for equality" }
   }))

   it("fails comparing enum to invalid literal string", util.check_type_error([[
      local type MyEnum = enum
         "foo"
         "bar"
      end
      local data: MyEnum = "foo"
      if data == "hello" then
         print("unreachable")
      end
   ]], {
      { msg = "not comparable for equality" }
   }))
end)

describe("flow analysis with ==", function()
   describe("on expressions", function()
      it("narrows type on expressions with and", util.check([[
         local x: number | string
         local y: string

         local s = x == y and x:lower()
      ]]))

      it("does not narrow type on expressions with or", util.check_type_error([[
         local x: number | string
         local n: number

         local s = x == n and tostring(x + 1) or x:lower()
      ]], {
         { msg = [[cannot index key 'lower' in union 'x' of type number | string]] }
      }))

      it("does not narrow type on expressions with not", util.check_type_error([[
         local x: number | string
         local y: string

         local s = not (x == y) and tostring(x + 1)
      ]], {
         { msg = "cannot use operator '+' for types number | string and integer" }
      }))
   end)

   describe("on if", function()
      it("resolves in both directions", util.check([[
         local t: number | string
         local n: number
         if n == t then
            print(t + 1)
         end
      ]]))

      it("resolves only on then branch", util.check_type_error([[
         local t: number | string
         if t == 9 then
            print(t + 1)
         else
            print(t:upper())
         end
      ]], {
         { msg = [[cannot index key 'upper' in union 't' of type number | string]] }
      }))

      it("can combine with is", util.check([[
         local function foo(a: number | string | function)
            if a is string and a == 'hello' then
               print(a:upper())
               return
            elseif a is string and a == 'bye' then
               print(a:lower())
               return
            end
         end

         foo('hello')
      ]]))

      it("propagates string constants for use as enums", util.check([[
         local enum Direction
            "north"
            "south"
            "east"
            "west"
         end

         local function f(d: Direction)
            print(d)
         end

         local s: string
         if s == "north" then
            f(s)
         end
      ]]))

      it("combines string constants for use as enums", util.check([[
         local enum Direction
            "north"
            "south"
            "east"
            "west"
         end

         local function f(d: Direction)
            print(d)
         end

         local s: string
         if s == "north" or s == "south" then
            f(s)
         end
      ]]))

      it("does not combine if not valid as enums", util.check_type_error([[
         local enum Direction
            "north"
            "south"
            "east"
            "west"
         end

         local function f(d: Direction)
            print(d)
         end

         local s: string
         if s == "north" or s == "bad" then
            f(s)
         end
      ]], {
         { msg = [[argument 1: got string "north" | string "bad" (inferred at foo.tl:13:26), expected Direction]] }
      }))

      it("works for type arguments", util.check([[
         local function test<T>(t: T)
            if t == 9 then
               print(t + 1)
            else
               print(t)
            end
         end
      ]]))

      it("works for not and type arguments", util.check([[
         local function test<T>(t: T)
            if not (t == 9) then
               print(t)
            else
               print(t + 1)
            end
         end
      ]]))

      it("does not narrow with not", util.check_type_error([[
         local t: number | string
         if not (t == 9) then
            print(t:upper())
         else
            print(t + 1)
         end
      ]], {
         { msg = [[cannot index key 'upper' in union 't' of type number | string]] }
      }))

      it("resolves with elseif", util.check([[
         local v: number | string | {boolean}
         if v == 9 then
            v = v + 1
         elseif v == "hello" then
            print(v:upper())
         end
      ]]))

      it("resolves with a type definition", util.check([[
         local type A = number
         local type B = record
           h: UnionAorB
           t: UnionAorB
         end
         local type UnionAorB = A | B
         local b: B = {}

         local function head(n: UnionAorB): UnionAorB
           if n == b then
             return n.h
           end
         end
      ]]))

      it("does not resolve incrementally", util.check_type_error([[
         local v: number | string | {boolean}
         if v == 2 then
            v = v + 1
         elseif v == "hello" then
            print(v:upper())
         else
            local b: {boolean} = v
         end
      ]], {
         { msg = "in local declaration: b: got number | string | {boolean}, expected {boolean}" }
      }))

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

      it("does not resolve partially", util.check_type_error([[
         local v: number | string | {boolean}
         if v == 9 then
            print(v + 1)
         else
            print(v:upper()) -- v is number | string | {boolean}
         end
      ]], {
         { msg = [[cannot index key 'upper' in union 'v' of type number | string | {boolean}]] }
      }))

      it("builds union types with == and or", util.check_type_error([[
         local v: number | boolean | {string}
         if (v == 9) or (v == true) then
            print(v + 1) -- ERR
         end
      ]], {
         { msg = "cannot use operator '+' for types integer | boolean" },
      }))

      it("builds union types with == and or (parses priorities correctly)", util.check_type_error([[
         local v: number | boolean | {string}
         if v == 9 or v == true then
            print(v + 1) -- ERR
         end
      ]], {
         { msg = "cannot use operator '+' for types integer | boolean" },
      }))
   end)

   describe("on while", function()
      it("widens unions on while to avoid errors", util.check_type_error([[
         local t: number | string
         t = 1
         if t == 1 then
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

      it("resolves == on the test", util.check([[
         local function process(ts: {number | string})
            local t: number | string
            t = ts[1]
            local i = 1
            local n: number = i
            while t == n do
               print(t + 1)
               i = i + 1
               t = ts[i]
               n = i
            end
         end
      ]]))
   end)
end)
