local util = require("spec.util")

describe("record function", function()
   describe("redeclaration: ", function()
      it("an inconsistent arity in redeclaration produces an error", util.check_type_error([[
         local record Y
         end

         function Y.do_x(a: integer, b: integer): integer
             return a + b
         end

         function Y.do_x(a: integer): integer
             return Y.do_x(a, 1)
         end
      ]], {
         { y = 8, msg = "type signature of 'do_x' does not match its declaration in Y: different number of input arguments: got 1, expected 2" },
      }))

      it("an inconsistent type in declaration produces an error", util.check_type_error([[
         local record Y
            do_x: function(integer, integer): integer
         end

         function Y.do_x(a: integer, b: string): integer
             return a + math.tointeger(b)
         end
      ]], {
         { y = 5, msg = "type signature of 'do_x' does not match its declaration in Y: argument 2: got string, expected integer" },
      }))

      it("an inconsistent type in redeclaration produces an error", util.check_type_error([[
         local record Y
         end

         function Y.do_x(a: integer, b: integer): integer
             return a + b
         end

         function Y.do_x(a: integer, b: string): integer
             return a + math.tointeger(b)
         end
      ]], {
         { y = 8, msg = "type signature of 'do_x' does not match its declaration in Y: argument 2: got string, expected integer" },
      }))

      it("cannot implement a polymorphic function via redeclaration", util.check_type_error([[
         local record Y
            do_x: function(integer, integer): integer
            do_x: function(integer): integer
         end

         function Y.do_x(a: integer, b: string): integer
             return a + math.tointeger(b)
         end
      ]], {
         { y = 6, msg = "type signature does not match declaration: field has multiple function definitions" },
      }))

      it("a consistent redeclaration produces a warning", util.check_warnings([[
         local record Y
         end

         function Y.do_x(a: integer, b: integer): integer
             return a + b
         end

         function Y.do_x(a: integer, b: integer): integer
             return a - b
         end
      ]], {
         { y = 8, msg = "function shadows previous declaration of 'do_x'" },
      }))

      it("a type signature does not count as a redeclaration", util.check_warnings([[
         local record Y
            do_x: function(integer, integer): integer
         end

         function Y.do_x(a: integer, b: integer): integer
             return a + b
         end
      ]], {}, {}))

      it("a type signature does not count as a redeclaration, but catches inconsistency", util.check_warnings([[
         local record Y
            do_x: function(Y, integer, integer): integer
         end

         function Y.do_x(a: integer, b: integer): integer
             return a + b
         end
      ]], {}, {
         { y = 5, msg = "different number of input arguments: got 2, expected 3" },
      }))

      pending("detect mismatch in function generics", util.check_type_error([[
         local type List2 = record<T>
             new: function<U>(initialItems: {T}, u: U): List2<T>
         end

         function List2.new<U>(initialItems: {T}, u: U): List2<U> -- mismatched return type
         end

         local type Fruit2 = enum
            "apple"
            "peach"
            "banana"
         end

         local type L2 = List2<Fruit2>
         local lunchbox = L2.new({"apple", "peach"}, true)
      ]], {
         { msg = "type signature does not match declaration" }
      }))

      it("report error in return args correctly (regression test for #618)", util.check_warnings([[
         local record R
           _current: R

           func: function(R)
         end

         function R:func(): boolean
           return self._current and self._current:func()
         end
      ]], {}, {
         { y = 7, msg = "different number of return values: got 1, expected 0" },
      }))

      it("does not close nested types too early (regression test for #775)", util.check([[
         -- declare a nested record
         local record mul
            record Fil
               mime: function(Fil)
            end
         end

         -- declare an alias
         local type Fil = mul.Fil

         -- this works
         function mul.Fil:new_method1(self: Fil)
         end

         -- should work as well for alias
         function Fil:new_method2(self: Fil)
         end
      ]]))

      it("method assignment does not corrupt internal record data structure", util.check([[
         local interface MAI
            x: integer
            my_func: function(self, integer)
         end

         local obj: MAI = { x = 20 }

         local record MR is MAI
            b: string
         end

         obj.my_func = function(self: MAI, n: integer)
         end

         function MR:my_func(n: integer)
         end
      ]]))
   end)
end)
