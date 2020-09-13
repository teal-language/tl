local util = require("spec.util")

describe("[]", function()
   describe("on records", function()
      it("ok if indexing by string", util.check [[
         local x = { foo = "f" }
         print(x["foo"])
      ]])

      it("fails even if record is homogenous", util.check_type_error([[
         local x = { foo = 12, bar = 24 }
         local y = "baz"
         local n: number = x[y]
      ]], {
         { msg = "cannot index object of type {foo: number, bar: number} with a string, consider using an enum" },
      }))

      it("fail without declaration if record is not homogenous", util.check_type_error([[
         local s = string.upper("hello")
         local x = { foo = 12, bar = s }
         local y = "baz"
         local n: string = x[y]
      ]], {
         { msg = "cannot index object of type {foo: number, bar: string} with a string, consider using an enum" },
      }))

      it("ok without declaration if key is enum and all keys map to the same type", util.check [[
         local Keys = enum
            "foo"
            "bar"
         end
         local x = { foo = 12, bar = 24, bla = "something else" }
         local e: Keys = "foo"
         local n: number = x[e]
      ]])

      it("fail if key is enum and not all keys map to the same type", util.check_type_error([[
         local Keys = enum
            "foo"
            "bar"
         end
         local x = { foo = 12, bar = true, bla = "something else" }
         local e: Keys = "foo"
         local n: number = x[e]
      ]], {
         { msg = "cannot index, not all enum values map to record fields of the same type" },
      }))

      it("fail if key is enum and not all keys are covered", util.check_type_error([[
         local Keys = enum
            "foo"
            "bar"
            "oops"
         end
         local x = { foo = 12, bar = 12, bla = "something else" }
         local e: Keys = "foo"
         local n: number = x[e]
      ]], {
         { msg = "enum value 'oops' is not a field" },
      }))

      it("fail if indexing by invalid string", util.check_type_error([[
         local x = { foo = "f" }
         print(x["bar"])
      ]], {
         { msg = "invalid key 'bar' in record 'x'" },
      }))
   end)
end)
