local tl = require("tl")
local util = require("spec.util")

describe("global", function()
   describe("is not a keyword and", function()
      it("works as a table key", util.check [[
         local t = {
            global = 12
         }
         print(t.global)
      ]])

      it("works in calls", util.check [[
         local global = 12
         print(global)
      ]])

      pending("works as a variable", util.check [[
         local global = 12
         global = 13
      ]])
   end)

   describe("undeclared", function()
      it("fails for single assignment", util.check_type_error([[
         x = 1
      ]], {
         { msg = "unknown variable: x" },
      }))

      it("fails for multiple assignment", util.check_type_error([[
         x, y = 1, 2
      ]], {
         { msg = "unknown variable: x" },
         { msg = "unknown variable: y" },
      }))
   end)

   describe("declared at top level", function()
      it("works for single assignment", util.check [[
         global x: number = 1
         x = 2
      ]])

      it("works for multiple assignment", util.check [[
         global x, y: number, string = 1, "hello"
         x = 2
         y = "world"
      ]])
   end)

   describe("declared at a deeper level", function()
      it("works for single assignment", util.check [[
         local function foo()
            global x: number = 1
            x = 2
         end
      ]])

      it("works for multiple assignment", util.check [[
         local function foo()
            global x, y: number, string = 1, "hello"
            x = 2
            y = "world"
         end
      ]])
   end)

   describe("redeclared", function()
      it("works if types are the same", util.check [[
         global x: number = 1
         global x: number
         x = 2
      ]])

      it("works for const if not reassigning", util.check [[
         global x <const>: number = 1
         global x <const>: number
      ]])

      it("fails for const if reassigning", util.check_type_error([[
         global x <const>: number = 1
         global x <const>: number = 9
      ]], {
         { msg = "cannot reassign to <const> global" },
      }))

      it("fails if adding const", util.check_type_error([[
         global x: number
         global x <const>: number
      ]], {
         { msg = "global was previously declared as not <const>" },
      }))

      it("fails if removing const", util.check_type_error([[
         global x <const>: number
         global x: number
      ]], {
         { msg = "global was previously declared as <const>" },
      }))

      it("fails if types don't match", util.check_type_error([[
         global x, y: number, string = 1, "hello"
         global x: string
         x = 2
         y = "world"
      ]], {
         { msg = "cannot redeclare global with a different type" },
      }))

      it("fails if types don't match", util.check_type_error([[
         local record AR
            {number}
         end

         global u: AR | number
         global u: {number} | number
      ]], {
         { msg = "cannot redeclare global with a different type" },
      }))
   end)

   describe("redeclared across files", function()
      it("works if types are the same", function()
         util.mock_io(finally, {
            ["foo.tl"] = "global x: number = 1"
         })
         util.check [[
            local foo = require("foo")
            global x: number
            x = 2
         ]]
      end)

      it("works for const if not reassigning", function()
         util.mock_io(finally, {
            ["foo.tl"] = "global x <const>: number = 1"
         })
         util.check [[
            local foo = require("foo")
            global x <const>: number
         ]]
      end)

      it("fails for const if reassigning", function()
         util.mock_io(finally, {
            ["foo.tl"] = "global x <const>: number = 1"
         })
         util.check_type_error([[
            local foo = require("foo")
            global x <const>: number = 9
         ]], {
            { msg = "cannot reassign to <const> global" },
         })
      end)

      it("fails if adding const", function()
         util.mock_io(finally, {
            ["foo.tl"] = "global x: number"
         })
         util.check_type_error([[
            local foo = require("foo")
            global x <const>: number
         ]], {
            { msg = "global was previously declared as not <const>" },
         })
      end)

      it("fails if removing const", function()
         util.mock_io(finally, {
            ["foo.tl"] = "global x <const>: number"
         })
         util.check_type_error([[
            local foo = require("foo")
            global x: number
         ]], {
            { msg = "global was previously declared as <const>" },
         })
      end)

      it("fails if types don't match", function()
         util.mock_io(finally, {
            ["foo.tl"] = "global x, y: number, string = 1, 'hello'"
         })
         util.check_type_error([[
            local foo = require("foo")
            global x: string
            x = 2
            y = "world"
         ]], {
            { msg = "cannot redeclare global with a different type" },
         })
      end)
   end)

end)
