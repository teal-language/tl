local util = require("spec.util")

describe("variadic type arguments", function()
   it("must be last type arguments in a generic declaration", util.check_syntax_error([[
      local bad: function<A..., B..., C>(C, A): boolean, B
   ]], {
      { y = 1, msg = "non-variadic type argument cannot follow variadic argument" }
   }))

   it("may have multiple variadic type arguments in a generic declaration", util.check [[
      local good: function<C, A..., B...>(C, A): boolean, B
   ]])

   it("must be last argument in a function type", util.check_type_error([[
      local bad: function<A..., B...>(A, number): boolean, B
   ]], {
      { y = 1, msg = "variadic type variables can only be the last argument" }
   }))

   describe("arity", function()
      it("non-variadic entries are arity checked alongside variadic", util.check_type_error([[
         local record R<A, B, C...>
         end

         local r: R<number> = {}
      ]], {
         { y = 4, msg = "mismatch in number of type arguments" }
      }))

      it("non-variadic entries are arity checked without variadic", util.check_type_error([[
         local record R<A, B>
         end

         local r: R<number> = {}
      ]], {
         { y = 4, msg = "mismatch in number of type arguments" }
      }))

      it("variadic entries can match to empty alongside non-variadic", util.check [[
         local record R<A, B, C...>
         end

         local r: R<number, string> = {}
      ]])

      it("variadic entries can match to empty without non-variadic", util.check [[
         local record R<C...>
         end

         local r: R<> = {}
      ]])
   end)

   for _, scope in ipairs({"local", "global"}) do
      it("must be last argument in a " .. scope .. " function", util.check_type_error([[
         ]] .. scope .. [[ function my_pcall<A..., B...>(f: function(A):(B), args: A, x: number): boolean, B
            return true, f(args)
         end
      ]], {
         { y = 1, msg = "variadic type variables can only be the last argument" }
      }))

      it("must be called '...' in a " .. scope .. " function", util.check_type_error([[
         ]] .. scope .. [[ function my_pcall<A..., B...>(f: function(A):(B), args: A): boolean, B
            return true, f(args)
         end
      ]], {
         { y = 1, msg = "variadic type variables can only be called '...'" }
      }))

      it("must be last return in a " .. scope .. " function", util.check_type_error([[
         ]] .. scope .. [[ function my_pcall<A..., B...>(f: function(A):(B), ...: A): boolean, B, boolean
            return true, f(...), true
         end
      ]], {
         { y = 1, msg = "variadic type variables can only be the last return type" }
      }))

      it("cannot be used in a " .. scope .. " declaration in a " .. scope .. " function", util.check_type_error([[
         ]] .. scope .. [[ function my_pcall<A..., B...>(f: function(A):(B), ...: A): boolean, B
            ]] .. scope .. [[ x: A
            return true, f(...)
         end
      ]], {
         { y = 2, msg = "variadic type variables can only be used in function signatures" }
      }))

      it("cannot be used in as part of another type in a " .. scope .. " function", util.check_type_error([[
         ]] .. scope .. [[ function my_pcall<A..., B...>(f: function(A):(B), ...: A): boolean, B
            ]] .. scope .. [[ x: {A}

            local record R
               attr: A
            end

            return true, f(...)
         end
      ]], {
         { y = 2, msg = "variadic type variables can only be used in function signatures" },
         { y = 5, msg = "variadic type variables can only be used in function signatures" },
      }))
   end

   it("can be declared", util.check [[
      local my_pcall: function<A..., B...>(function(A):(B), A): boolean, B

      local f = function(a: number, b: string): string, boolean
         return "hello " .. b, a > 10
      end

      local pok, msg, high = my_pcall(f, 42, "hisham")
      if pok then
         print(msg .. "!")
         local b: boolean = high
         if b then
            print("number > 10")
         end
      end
   ]])

   it("can catch an inconsistency through input arguments", util.check_type_error([[
      local my_pcall: function<A..., B...>(function(A):(B), A): boolean, B

      local f = function(a: number, b: string): string, boolean
         return "hello " .. b, a > 10
      end

      local pok, msg, high = my_pcall(f, "not a number!", "hisham")
      if pok then
         print(msg .. "!")
         if high then
            print("number > 10")
         end
      end
   ]], {
      { y = 7, msg = 'got string "not a number!", expected number' }
   }))

   it("can catch an inconsistency in return arity", util.check_type_error([[
      local my_pcall: function<A..., B...>(function(A):(B), A): boolean, B

      local f = function(a: number, b: string): string, boolean
         return "hello " .. b, a > 10
      end

      local pok, msg, high, wat = my_pcall(f, 42, "hisham")
   ]], {
      { y = 7, msg = "assignment in declaration did not produce an initial value for variable 'wat'" }
   }))
end)
