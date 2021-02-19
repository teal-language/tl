local util = require("spec.util")

describe("array argument", function()
   it("catches error in array elements", util.check_type_error([[
      local function a(arg: {string})
         print(arg)
      end

      local function main()
         a({"a", 100})
         a(100)
      end
   ]], {
      { y = 6, msg = 'expected an array: at index 2: got number, expected string' },
      { y = 7, msg = 'argument 1: got number, expected {string}' },
   }))

   it("constructs type of complex array correctly (#111)", util.check_type_error([[
      local type MyRecord = record
         func: function<K, V>(t: {{K:V}}): {V}
      end

      local x: {string} = MyRecord.func({
         {id = 2},
         {otherkey = "hello"},
         {id = "yo"},
      })
   ]], {
      { y = 5, "got {number | string}, expected {string}"},
      { y = 7, "in array: at index 2: got {number | string}, expected {string}"},
      { y = 8, "in array: at index 3: got {number | string}, expected {string}"},
   }))

end)
