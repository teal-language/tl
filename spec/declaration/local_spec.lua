local util = require("spec.util")

describe("local", function()
   describe("declaration", function()
      it("basic inference sets types, fail", util.check_type_error([[
         local x = 1
         local y = 2
         local z: table
         z = x + y
      ]], {
         { msg = "in assignment: got number" },
      }))

      it("basic inference sets types, pass", util.check [[
         local x = 1
         local y = 2
         local z: number
         z = x + y
      ]])
   end)

   describe("multiple declaration", function()
      it("basic inference catches errors", util.check_type_error([[
         local x, y = 1, 2
         local z: table
         z = x + y
      ]], {
         { msg = "in assignment: got number" },
      }))

      it("basic inference sets types", util.check [[
         local x, y = 1, 2
         local z: number
         z = x + y
      ]])

      describe("with types", function()
         it("checks values", util.check_type_error([[
            local x, y: string, number = 1, "a"
            local z
            z = x + string.byte(y)
         ]], {
            { msg = "x: got number, expected string" },
            { msg = "y: got string \"a\", expected number" },
            { msg = "variable 'z' has no type" },
            { msg = "cannot use operator '+'" },
            { msg = "argument 1: got number, expected string" },
         }))

         it("propagates correct type", util.check_type_error([[
            local x, y: number, string = 1, "a"
            local z: table
            z = x + string.byte(y)
         ]], {
            { msg = "in assignment: got number" },
         }))

         it("uses correct type", util.check [[
            local x, y: number, string = 1, "a"
            local z: number
            z = x + string.byte(y)
         ]])
      end)

      it("reports unset and untyped values as errors in tl mode", util.check_type_error([[
         local type T = record
            x: number
            y: number
         end

         function T:returnsTwo(): number, number
            return self.x, self.y
         end

         function T:method()
            local a, b = self.returnsTwo and self:returnsTwo()
         end
      ]], {
         { msg = "assignment in declaration did not produce an initial value for variable 'b'" },
      }))

      it("reports unset values as unknown in Lua mode", util.lax_check([[
         local type T = record
            x: number
            y: number
         end

         function T:returnsTwo(): number, number
            return self.x, self.y
         end

         function T:method()
            local a, b = self.returnsTwo and self:returnsTwo()
         end
      ]], {
         { msg = "b" },
      }))

      it("'type', 'record' and 'enum' are not reserved keywords", util.check [[
         local type = type
         local record: string = "hello"
         local enum: number = 123
         print(record)
         print(enum + 123)
      ]])
   end)
end)
