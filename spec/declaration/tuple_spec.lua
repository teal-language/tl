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
      local a: {number, string} = { [-1] = "hi" } -- infers to {string}
      local b: {number, string} = { "hi" } -- infers to {string}
      local c: {string, number} = { [-1] = "hi" } -- infers to {string}
      local d: {string, number} = { "hi" } -- infers to {string}
   ]], {
      { y = 1, msg = "in local declaration: a: tuple entry 1 of type number does not match type of array elements, which is string" },
      { y = 2, msg = "in local declaration: b: tuple entry 1 of type number does not match type of array elements, which is string" },
      { y = 3, msg = "in local declaration: c: tuple entry 2 of type number does not match type of array elements, which is string" },
      { y = 4, msg = "in local declaration: d: tuple entry 2 of type number does not match type of array elements, which is string" },
   }))

   it("should report when a tuple has incompatible entries", util.check_type_error([[
      local b: {number, string} = { 1, false }
   ]], {
      { y = 1, msg = "in local declaration: b: in tuple entry 2: got boolean, expected string" },
   }))

   it("should report when a tuple literal is longer than annotated type", util.check_type_error([[
     local c: {number, string} = { 1, "hello", 10 }
   ]], {
      { y = 1, msg = "in local declaration: c: tuple {1: number, 2: string, 3: number} is too big for tuple {1: number, 2: string}" },
   }))

   it("should work with explicit integer indices", util.check [[
      local a: {number, string} = { [1] = 10, [2] = "hello" }
      local b: {number, string} = { [2] = "hello", [1] = 10 }
   ]])

   pending("should error with explicit integer indices that are out of range", util.check_type_error([[
      local c: {number, string} = { [-1] = 10 }
   ]], {
      { msg = "in local declaration: c: got {number : number}, expected {1: number, 2: string}" },
   }))
end)
