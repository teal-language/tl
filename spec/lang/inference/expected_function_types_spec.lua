local util = require("spec.util")

describe("expected function types", function()
   it("stores expected type on function in variable assignment", util.check([[
      local f: function(integer): string = function(x)
         return tostring(x)
      end
   ]]))

   it("stores expected type on function in function argument", util.check([[
      local function call_with_function(f: function(integer): string): string
         return f(42)
      end

      call_with_function(function(x)
         return tostring(x)
      end)
   ]]))

   it("stores expected type on function in return statement", util.check([[
      local function get_handler(): function(integer): string
         return function(x)
            return tostring(x)
         end
      end
   ]]))

   it("stores expected type on function in table field", util.check([[
      local record Handler
         on_click: function(integer): string
      end

      local h: Handler = {
         on_click = function(x)
            return tostring(x)
         end
      }
   ]]))

   it("stores expected type on function in parenthesized expression", util.check([[
      local f: function(integer): string = (function(x)
         return tostring(x)
      end)
   ]]))

   it("handles function without expected type gracefully", util.check([[
      local f = function(x)
         return tostring(x)
      end
   ]]))

   it("handles function with unannotated parameters and expected type", util.check([[
      local f: function(integer): string = function(x)
         return tostring(x)
      end
   ]]))

   it("handles function with unannotated parameters and no expected type", util.check([[
      local f = function(x)
         return tostring(x)
      end
   ]]))

   it("isolates expected types between multiple functions", util.check([[
      local f1: function(integer): string = function(x)
         return tostring(x)
      end

      local f2: function(number): number = function(y)
         return y + 1
      end
   ]]))

   it("handles nested functions with different expected types", util.check([[
      local function outer(): function(integer): string
         return function(x)
            return tostring(x)
         end
      end

      local function inner(f: function(integer): string): string
         return f(42)
      end

      inner(outer())
   ]]))

   it("handles function in logical operator with expected type", util.check([[
      local condition = true
      local f: function(integer): string = condition and function(x)
         return tostring(x)
      end or function(y)
         return tostring(y)
      end
   ]]))

   it("handles function with annotated parameters and expected type", util.check([[
      local f: function(integer): string = function(x: integer)
         return tostring(x)
      end
   ]]))

   it("handles function with partial parameter annotations", util.check([[
      local f: function(integer, string): string = function(x: integer, y)
         return tostring(x) .. y
      end
   ]]))

   it("handles function with varargs and expected type", util.check([[
      local f: function(...: integer): string = function(...: integer)
         return "ok"
      end
   ]]))

   it("handles function with return type annotation and expected type", util.check([[
      local f: function(integer): string = function(x): string
         return tostring(x)
      end
   ]]))

   it("handles multiple functions in sequence with different expected types", util.check([[
      local f1: function(integer): string = function(x)
         return tostring(x)
      end

      local f2: function(number): number = function(y)
         return y + 1
      end

      local f3: function(string): boolean = function(z)
         return z == "ok"
      end
   ]]))

   it("handles function in table with multiple fields", util.check([[
      local record Handlers
         on_click: function(integer): string
         on_hover: function(number): boolean
      end

      local h: Handlers = {
         on_click = function(x)
            return tostring(x)
         end,
         on_hover = function(y)
            return y > 0
         end
      }
   ]]))

   it("handles function passed to function with multiple parameters", util.check([[
      local function apply(f: function(integer): string, x: integer): string
         return f(x)
      end

      apply(function(n)
         return tostring(n)
      end, 42)
   ]]))

   it("handles function in array-like table with expected type", util.check([[
      local handlers: {function(integer): string} = {
         function(x)
            return tostring(x)
         end,
         function(y)
            return tostring(y)
         end
      }
   ]]))

end)
