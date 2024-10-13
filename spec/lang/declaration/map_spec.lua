local util = require("spec.util")

describe("maps", function()
   it("catches redeclaration of literal string keys", util.check_type_error([[
      local foo: {string: string} = {}
      foo = {
         ["foo"] = "hello",
         ["bar"] = "oi",
         ["foo"] = "wat",
      }
   ]], {
      { y = 5, msg = "redeclared key foo" }
   }))

   it("catches redeclaration of literal numeric keys", util.check_type_error([[
      local foo: {number: string} = {}
      foo = {
         [1.0] = "hello",
         [0.5] = "oi",
         [1] = "wat",
         [0.5000] = "oi",
      }
   ]], {
      { y = 5, msg = "redeclared key 1 " },
      { y = 6, msg = "redeclared key 0.5 " },
   }))

   it("catches redeclaration of literal boolean keys", util.check_type_error([[
      local foo: {boolean: string} = {}
      foo = {
         [true] = "hello",
         [false] = "oi",
         [false] = "wat",
         [true] = "oi",
      }
   ]], {
      { y = 5, msg = "redeclared key false" },
      { y = 6, msg = "redeclared key true" },
   }))

   it("redeclaration check does not fail on non-literal boolean keys (regression test for #816)", util.check([[
      local KEY_FALSE = false
      local KEY_TRUE  = true

      local foo = {
          [false] = "false",
          [true]  = "true",
      }

      local bar = {
          [KEY_FALSE] = "false",
          [KEY_TRUE]  = "true",
      }

      print(foo[false])
      print(foo[true])

      print(bar[KEY_FALSE])
      print(bar[KEY_TRUE])
   ]]))
end)
