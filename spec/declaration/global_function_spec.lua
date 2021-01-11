local util = require("spec.util")

describe("global function", function()
   describe("type", function()
      it("can have anonymous arguments", util.check [[
         global f: function(number, string): boolean

         f = function(a: number, b: string): boolean
            return #b == a
         end
         local ok = f(3, "abc")
      ]])

      it("can have type variables", util.check [[
         global f: function<a, b, c>(a, b): c

         f = function(a: number, b: string): boolean
            return #b == a
         end
         local ok = f(3, "abc")
      ]])

      it("can take names in arguments but names are ignored", util.check [[
         global f: function(x: number, y: string): boolean

         f = function(a: number, b: string): boolean
            return #b == a
         end
         local ok = f(3, "abc")
      ]])

      it("can take typed vararg in arguments", util.check [[
         global f: function(x: number, ...: string): boolean

         f = function(a: number, ...: string): boolean
            return #select(1, ...) == a
         end
         local ok = f(3, "abc")
      ]])

      it("cannot take untyped vararg", util.check_syntax_error([[
         global f: function(number, ...): boolean

         f = function(a: number, ...: string): boolean
            return #select(1, ...) == a
         end
         local ok = f(3, "abc")
      ]], {
         { msg = "cannot have untyped '...' when declaring the type of an argument" }
      }))
   end)

   for _, decl in ipairs({ "function", "global function" }) do
      describe("'" .. decl .. "'", function()
         it("declaration", util.check([[
            ]] .. decl .. [[ f(a: number, b: string): boolean
               return #b == a
            end
            local ok = f(3, "abc")
         ]]))

         it("declaration with type variables", util.check([[
            ]] .. decl .. [[ f<a, b>(a1: a, a2: a, b1: b, b2: b): b
               if a1 == a2 then
                  return b1
               else
                  return b2
               end
            end
            local ok = f(10, 20, "hello", "world")
         ]]))

         it("declaration with nil as return", util.check([[
            ]] .. decl .. [[ f(a: number, b: string): nil
               return
            end
            local ok = f(3, "abc")
         ]]))

         it("declaration with no return", util.check([[
            ]] .. decl .. [[ f(a: number, b: string): ()
               return
            end
            f(3, "abc")
         ]]))

         it("declaration with no return cannot be used in assignment", util.check_type_error([[
            ]] .. decl .. [[ f(a: number, b: string): ()
               return
            end
            local x = f(3, "abc")
         ]], {
            { msg = "assignment in declaration did not produce an initial value for variable 'x'" }
         }))

         it("declaration with return nil can be used in assignment", util.check([[
            ]] .. decl .. [[ f(a: number, b: string): nil
               return
            end
            local x = f(3, "abc")
         ]]))

         describe("with function arguments", function()
            it("has ambiguity without parentheses in function type return", util.check_syntax_error([[
               ]] .. decl .. [[ map<a, b>(f: function(a):b, xs: {a}): {b}
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
            ]], {
               { y = 1, x = 47 + #decl, msg = "syntax error" },
               { y = 1 },
               { y = 1 },
               { y = 1 },
            }))

            it("has no ambiguity with parentheses in function type return", util.check([[
               ]] .. decl .. [[ map<a,b>(f: function(a):(b), xs: {a}): {b}
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
      end)
   end
end)
