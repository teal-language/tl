local util = require("spec.util")

describe("local function", function()
   describe("type", function()
      it("can have anonymous arguments", util.check([[
         local f: function(number, string): boolean

         f = function(a: number, b: string): boolean
            return #b == a
         end
         local ok = f(3, "abc")
      ]]))

      it("can have type variables", util.check([[
         local f: function<a, b>(a, b): a

         f = function(a: number, b: string): number
            return a + #b
         end
         local ok = f(3, "abc")
      ]]))

      it("can have type variables with constraints", util.check([[
         local type F = function(any...): any...

         local function partial<T is F>(f: T, a: any): T
            return function(...: any): any...
               return f(a, ...)
            end
         end
      ]]))

      it("cannot have unused type variables", util.check_type_error([[
         local function f<Z>(a: number, b: string): ()
            return
         end
      ]], {
         { msg = "type argument 'Z' is not used in function signature" }
      }))

      it("can take names in arguments but names are ignored", util.check([[
         local f: function(x: number, y: string): boolean

         f = function(a: number, b: string): boolean
            return #b == a
         end
         local ok = f(3, "abc")
      ]]))

      it("can take typed vararg in arguments", util.check([[
         local f: function(x: number, ...: string): boolean

         f = function(a: number, ...: string): boolean
            return #select(1, ...) == a
         end
         local ok = f(3, "abc")
      ]]))

      it("can take return-style input varargs in type declarations", util.check([[
         local f: function(x: number, string...): boolean

         f = function(a: number, ...: string): boolean
            return #select(1, ...) == a
         end
         local ok = f(3, "abc")
      ]]))

      it("cannot take return-style input varargs in function declarations", util.check_syntax_error([[
         local f: function(x: number, string...): boolean

         f = function(a: number, string...): boolean
            return #select(1, ...) == a
         end
         local ok = f(3, "abc")
      ]], {
         { y = 3, msg = "'...' needs to be declared as a typed argument" }
      }))

      it("can take typed vararg in return types", util.check([[
         local f: function(x: number): string...

         f = function(x: number): string...
            return "hello", "world"
         end

         local s1, s2 = f(123)
         local x = s1 .. s2
      ]]))

      it("can take parenthesized typed vararg in return types", util.check([[
         local f: function(x: number): (number, string...)

         f = function(x: number): (number, string...)
            return 9, "hello", "world"
         end

         local n, s1, s2 = f(123)
         local x = s1 .. s2 .. tostring(math.floor(n))
      ]]))

      it("cannot take untyped vararg", util.check_syntax_error([[
         local f: function(number, ...): boolean

         f = function(a: number, ...: string): boolean
            return #select(1, ...) == a
         end
         local ok = f(3, "abc")
      ]], {
         { msg = "cannot have untyped '...' when declaring the type of an argument" }
      }))

      it("vararg can only be the last argument", util.check_syntax_error([[
         local f: function(...: string, number): boolean
         local g: function(string, string..., number): boolean

         f = function(...: string, a: number): boolean
            return #select(1, ...) == a
         end
         local ok = f(3, "abc")
      ]], {
         { y = 1, msg = "'...' can only be last argument" },
         { y = 2, msg = "'...' can only be last argument" },
         { y = 4, msg = "'...' can only be last argument" },
      }))

      it("does not get multiple uses of base types confused (regression test for #679)", util.check([[
         local f: function(x: number, s: string, string...): boolean
         local g: function(x: number, s: string, ...: string): boolean
      ]]))
   end)

   it("declaration", util.check([[
      local function f(a: number, b: string): boolean
         return #b == a
      end
      local ok = f(3, "abc")
   ]]))

   it("declaration with type variables", util.check([[
      local function f<a, b>(a1: a, a2: a, b1: b, b2: b): b
         if a1 == a2 then
            return b1
         else
            return b2
         end
      end
      local ok = f(10, 20, "hello", "world")
   ]]))

   it("declaration with nil as return", util.check([[
      local function f(a: number, b: string): nil
         return
      end
      local ok = f(3, "abc")
   ]]))

   it("declaration with no return", util.check([[
      local function f(a: number, b: string): ()
         return
      end
      f(3, "abc")
   ]]))

   it("declaration with no return cannot be used in assignment", util.check_type_error([[
      local function f(a: number, b: string): ()
         return
      end
      local x = f(3, "abc")
   ]], {
      { msg = "assignment in declaration did not produce an initial value for variable 'x'" }
   }))

   it("declaration with return nil can be used in assignment", util.check([[
      local function f(a: number, b: string): nil
         return
      end
      local x = f(3, "abc")
   ]]))

   describe("with function arguments", function()
      it("has no ambiguity without parentheses in function type return", util.check([[
         local function map<a, b>(f: function(a):b, xs: {a}): {b}
            local r = {}
            for i, x in ipairs(xs) do
               r[i] = f(x)
            end
            return r
         end
         local function quoted(s: string): string
            return "'" .. s .. "'"
         end

         print(table.concat(map(quoted, {"red", "green", "blue"}), ", "))
      ]]))

      it("has no ambiguity with parentheses in function type return", util.check([[
         local function map<a,b>(f: function(a):(b), xs: {a}): {b}
            local r = {}
            for i, x in ipairs(xs) do
               r[i] = f(x)
            end
            return r
         end
         local function quoted(s: string): string
            return "'" .. s .. "'"
         end

         print(table.concat(map(quoted, {"red", "green", "blue"}), ", "))
      ]]))
   end)

   describe("shadowing", function()
      it("arguments shadow variables", util.check([[
         local record Name
            normal: string
            folded: string
         end

         local normal: number

         local function new(normal: string): Name
            return {
               normal = normal:upper()
            }
         end
      ]]))

      it("arguments shadow variables but not argument types", util.check([[
         local record CaseMapping
            upper: string
            lower: string
         end

         local casemap = {
            CaseMapping = CaseMapping
         }

         local record Name
            normal: string
            folded: string
         end

         local normal: number

         -- argument casemap does not shadow casemap in type casemap.CaseMapping
         function Name.new(normal: string, casemap: casemap.CaseMapping): Name
            return {
               normal = normal:upper()
            }
         end

         return {
            Name = Name;
         }
      ]]))
   end)
end)
