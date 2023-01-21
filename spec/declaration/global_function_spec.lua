local util = require("spec.util")

describe("global function", function()
   describe("type", function()
      it("can have anonymous arguments", util.check([[
         global f: function(number, string): boolean

         f = function(a: number, b: string): boolean
            return #b == a
         end
         local ok = f(3, "abc")
      ]]))

      it("can have type variables", util.check([[
         global f: function<a, b>(a, b): a

         f = function(a: number, b: string): number
            return a + #b
         end
         local ok = f(3, "abc")
      ]]))

      it("can take names in arguments but names are ignored", util.check([[
         global f: function(x: number, y: string): boolean

         f = function(a: number, b: string): boolean
            return #b == a
         end
         local ok = f(3, "abc")
      ]]))

      it("can take typed vararg in arguments", util.check([[
         global f: function(x: number, ...: string): boolean

         f = function(a: number, ...: string): boolean
            return #select(1, ...) == a
         end
         local ok = f(3, "abc")
      ]]))

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

   it("a bare 'function' can only be used in lax mode", util.check_type_error([[
      function f()
         print("I am a bare function")
      end
   ]], {
      { y = 1, msg = "functions need an explicit 'local' or 'global' annotation" },
   }))

   it("a function can be pre-declared", util.check([[
      local f: function()
      function f()
         print("I am a bare function")
      end
   ]]))

   local modes = {
      {
         fn = "function",
         check = function(code) return util.lax_check(code, {}) end,
         check_type_error = util.lax_check_type_error,
         check_syntax_error = util.check_syntax_error,
      },
      {
         fn = "global function",
         check = util.check,
         check_type_error = util.check_type_error,
         check_syntax_error = util.check_syntax_error,
      },
   }

   for _, mode in ipairs(modes) do
      describe("'" .. mode.fn .. "'", function()
         it("declaration", mode.check([[
            ]] .. mode.fn .. [[ f(a: number, b: string): boolean
               return #b == a
            end
            local ok = f(3, "abc")
         ]]))

         it("declaration with type variables", mode.check([[
            ]] .. mode.fn .. [[ f<a, b>(a1: a, a2: a, b1: b, b2: b): b
               if a1 == a2 then
                  return b1
               else
                  return b2
               end
            end
            local ok = f(10, 20, "hello", "world")
         ]]))

         it("declaration with nil as return", mode.check([[
            ]] .. mode.fn .. [[ f(a: number, b: string): nil
               return
            end
            f(3, "abc")
         ]]))

         it("declaration with no return", mode.check([[
            ]] .. mode.fn .. [[ f(a: number, b: string): ()
               return
            end
            f(3, "abc")
         ]]))

         it("declaration with no return cannot be used in assignment", mode.check_type_error([[
            ]] .. mode.fn .. [[ f(a: number, b: string): ()
               return
            end
            local x = f(3, "abc")
         ]], mode.fn == "global function"
             and {{ msg = "assignment in declaration did not produce an initial value for variable 'x'" }}
             or  {}))

         it("declaration with return nil can be used in assignment", mode.check([[
            ]] .. mode.fn .. [[ f(a: number, b: string): nil
               return
            end
            local x: nil = f(3, "abc")
         ]]))

         describe("with function arguments", function()
            it("has ambiguity without parentheses in function type return", mode.check_syntax_error([[
               ]] .. mode.fn .. [[ map<a, b>(f: function(a):b, xs: {a}): {b}
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
               { y = 1, x = 47 + #mode.fn, msg = "syntax error" },
               { y = 1 },
               { y = 1 },
               { y = 1 },
            }))

            it("has no ambiguity with parentheses in function type return", mode.check([[
               ]] .. mode.fn .. [[ map<a,b>(f: function(a):(b), xs: {a}): {b}
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

   describe("shadowing", function()
      it("cannot define a global function when a local function with the same name is in scope", util.check_type_error([[
         local function test()
            local boo: string = "1"
         end

         global function test()
            local boo: string = "1"
         end
      ]], {
         { y = 5, msg = "cannot define a global when a local with the same name is in scope" },
      }))

      it("cannot define a global function when a local variable with the same name is in scope", util.check_type_error([[
         local test: integer

         global function test()
            local boo: string = "1"
         end
      ]], {
         { y = 3, msg = "cannot define a global when a local with the same name is in scope" },
      }))

      it("cannot be annotated as 'global'", util.check_syntax_error([[
         local tbl = {}

         -- this function is stored in a table field, not in a global variable
         global function tbl.say(something: string)
           print(something)
         end
      ]], {
         { y = 4, msg = "record functions cannot be annotated as 'global'" },
      }))
   end)
end)
