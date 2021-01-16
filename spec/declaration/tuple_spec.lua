local util = require("spec.util")

describe("tuple declarations", function()
   it("can be simple", util.check [[
      local x = { 1, "hi" }
   ]])

   it("can be declared as a nominal type", util.check [[
      local type Coords = {number, number}
      local c: Coords = { 1, 2 }
   ]])

   it("should report when an array literal is too long to fit within tuple type", util.check_type_error([[
      local a: {number, number} = {1, 2, 3}
   ]], {
      { y = 1, msg = "in local declaration: a: incompatible length, expected maximum length of 2, got 3" }
   }))

   it("should report when an array is of incorrect type of a tuple entry", util.check_type_error([[
      local a: {number, string} = { [-1] = "hi" } -- infers to {string} with a length of 0, which is incompatible with {number, string}
      local b: {number, string} = { "hi" } -- infers to {string} with a length of 1, which is incompatible with {number, string}
      local c: {string, number} = { [-1] = "hi" } -- infers to {string} with a length of 0, which should maybe be compatible with {string, number}?
   ]], {
      { y = 1, msg = "in local declaration: a: tuple entry 1 of type number does not match type of array elements, which is string" },
      { y = 2, msg = "in local declaration: b: tuple entry 1 of type number does not match type of array elements, which is string" },
      { y = 3, msg = "in local declaration: c: tuple entry 2 of type number does not match type of array elements, which is string" },
   }))

   it("should allow array literals that fit within then tuple length", util.check [[
      local a: {number, string} = { 1 }
      local b: {boolean, boolean, number} = { false, true }
      local c: {string, number} = { "hi" }
   ]])

   it("should report when a tuple has incompatible entries", util.check_type_error([[
      local b: {number, string} = { 1, false }
   ]], {
      { y = 1, msg = "in local declaration: b: in tuple entry 2: got boolean, expected string" },
   }))

   it("should report when a tuple literal is longer than annotated type", util.check_type_error([[
     local c: {number, string} = { 1, "hello", 10 }
   ]], {
      { y = 1, msg = "in local declaration: c: tuple {number, string, number} is too big for tuple {number, string}" },
   }))

   it("should work with explicit integer indices", util.check [[
      local a: {number, string} = { [1] = 10, [2] = "hello" }
      local b: {number, string} = { [2] = "hello", [1] = 10 }
   ]])

   describe("fixed length array syntactic sugar", function()
      it("should not error", util.check [[
         local _arr: { 3 of number }
      ]])
      it("should be compatible with regular tuples", util.check [[
         local _a: { 3 of number } = {} as {number, number, number}
      ]])
      it("should be used when showing a unary tuple", util.check_warnings([[
         local a: { 1 of number }
      ]], {
         { y = 1, msg = "unused variable a: {1 of number}"}
      }))
      it("should report an error when something other than a positive integer is used", util.check_syntax_error([[
         local arr: {1.5 of number}
      ]], {
         { y = 1, msg = "expected a positive integer, got 1.5" }
      }))
   end)
end)
