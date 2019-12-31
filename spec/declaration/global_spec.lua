local tl = require("tl")
local util = require("spec.util")

describe("global", function()
   describe("is not a keyword and", function()
      it("works as a table key", function()
         local tokens = tl.lex([[
            local t = {
               global = 12
            }
            print(t.global)
         ]])
         local syntax_errors = {}
         local _, ast = tl.parse_program(tokens, syntax_errors)
         assert.same({}, syntax_errors)
         local errors, unknowns = tl.type_check(ast)
         assert.same({}, errors)
      end)

      it("works in calls", function()
         local tokens = tl.lex([[
            local global = 12
            print(global)
         ]])
         local syntax_errors = {}
         local _, ast = tl.parse_program(tokens, syntax_errors)
         assert.same({}, syntax_errors)
         local errors, unknowns = tl.type_check(ast)
         assert.same({}, errors)
      end)

      pending("works as a variable", function()
         local tokens = tl.lex([[
            local global = 12
            global = 13
         ]])
         local syntax_errors = {}
         local _, ast = tl.parse_program(tokens, syntax_errors)
         assert.same({}, syntax_errors)
         local errors, unknowns = tl.type_check(ast)
         assert.same({}, errors)
      end)
   end)

   describe("undeclared", function()
      it("fails for single assignment", function()
         local tokens = tl.lex([[
            x = 1
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors, unknowns = tl.type_check(ast)
         assert.same("unknown variable: x", errors[1].msg)
         assert.same(0, #unknowns)
      end)

      it("fails for multiple assignment", function()
         local tokens = tl.lex([[
            x, y = 1, 2
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors, unknowns = tl.type_check(ast)
         assert.same("unknown variable: x", errors[1].msg)
         assert.same("unknown variable: y", errors[2].msg)
         assert.same(0, #unknowns)
      end)
   end)

   describe("declared at top level", function()
      it("works for single assignment", function()
         local tokens = tl.lex([[
            global x: number = 1
            x = 2
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors, unknowns = tl.type_check(ast)
         assert.same({}, errors)
         assert.same(0, #unknowns)
      end)

      it("works for multiple assignment", function()
         local tokens = tl.lex([[
            global x, y: number, string = 1, "hello"
            x = 2
            y = "world"
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors, unknowns = tl.type_check(ast)
         assert.same({}, errors)
         assert.same(#unknowns, 0)
      end)
   end)

   describe("declared at a deeper level", function()
      it("works for single assignment", function()
         local tokens = tl.lex([[
            local function foo()
               global x: number = 1
               x = 2
            end
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors, unknowns = tl.type_check(ast)
         assert.same({}, errors)
         assert.same(0, #unknowns)
      end)

      it("works for multiple assignment", function()
         local tokens = tl.lex([[
            local function foo()
               global x, y: number, string = 1, "hello"
               x = 2
               y = "world"
            end
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors, unknowns = tl.type_check(ast)
         assert.same({}, errors)
         assert.same(#unknowns, 0)
      end)
   end)

   describe("redeclared", function()
      it("works if types are the same", function()
         local tokens = tl.lex([[
            global x: number = 1
            global x: number
            x = 2
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors, unknowns = tl.type_check(ast)
         assert.same({}, errors)
         assert.same(0, #unknowns)
      end)

      it("works for const if not reassigning", function()
         local tokens = tl.lex([[
            global x <const>: number = 1
            global x <const>: number
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors, unknowns = tl.type_check(ast)
         assert.same({}, errors)
         assert.same(0, #unknowns)
      end)

      it("fails for const if reassigning", function()
         local tokens = tl.lex([[
            global x <const>: number = 1
            global x <const>: number = 9
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors, unknowns = tl.type_check(ast)
         assert.match("cannot reassign to <const> global", errors[1].msg, 1, true)
         assert.same(0, #unknowns)
      end)

      it("fails if adding const", function()
         local tokens = tl.lex([[
            global x: number
            global x <const>: number
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors, unknowns = tl.type_check(ast)
         assert.match("global was previously declared as not <const>", errors[1].msg, 1, true)
         assert.same(0, #unknowns)
      end)

      it("fails if removing const", function()
         local tokens = tl.lex([[
            global x <const>: number
            global x: number
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors, unknowns = tl.type_check(ast)
         assert.match("global was previously declared as <const>", errors[1].msg, 1, true)
         assert.same(0, #unknowns)
      end)

      it("fails if types don't match", function()
         local tokens = tl.lex([[
            global x, y: number, string = 1, "hello"
            global x: string
            x = 2
            y = "world"
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors, unknowns = tl.type_check(ast)
         assert.match("cannot redeclare global with a different type", errors[1].msg, 1, true)
         assert.same(#unknowns, 0)
      end)
   end)

   describe("redeclared across files", function()
      it("works if types are the same", function()
         util.mock_io(finally, {
            ["foo.tl"] = "global x: number = 1"
         })
         local tokens = tl.lex([[
            local foo = require("foo")
            global x: number
            x = 2
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors, unknowns = tl.type_check(ast)
         assert.same({}, errors)
         assert.same(0, #unknowns)
      end)

      it("works for const if not reassigning", function()
         util.mock_io(finally, {
            ["foo.tl"] = "global x <const>: number = 1"
         })
         local tokens = tl.lex([[
            local foo = require("foo")
            global x <const>: number
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors, unknowns = tl.type_check(ast)
         assert.same({}, errors)
         assert.same(0, #unknowns)
      end)

      it("fails for const if reassigning", function()
         util.mock_io(finally, {
            ["foo.tl"] = "global x <const>: number = 1"
         })
         local tokens = tl.lex([[
            local foo = require("foo")
            global x <const>: number = 9
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors, unknowns = tl.type_check(ast)
         assert.match("cannot reassign to <const> global", errors[1].msg, 1, true)
         assert.same(0, #unknowns)
      end)

      it("fails if adding const", function()
         util.mock_io(finally, {
            ["foo.tl"] = "global x: number"
         })
         local tokens = tl.lex([[
            local foo = require("foo")
            global x <const>: number
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors, unknowns = tl.type_check(ast)
         assert.match("global was previously declared as not <const>", errors[1].msg, 1, true)
         assert.same(0, #unknowns)
      end)

      it("fails if removing const", function()
         util.mock_io(finally, {
            ["foo.tl"] = "global x <const>: number"
         })
         local tokens = tl.lex([[
            local foo = require("foo")
            global x: number
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors, unknowns = tl.type_check(ast)
         assert.match("global was previously declared as <const>", errors[1].msg, 1, true)
         assert.same(0, #unknowns)
      end)

      it("fails if types don't match", function()
         util.mock_io(finally, {
            ["foo.tl"] = "global x, y: number, string = 1, 'hello'"
         })
         local tokens = tl.lex([[
            local foo = require("foo")
            global x: string
            x = 2
            y = "world"
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors, unknowns = tl.type_check(ast)
         assert.match("cannot redeclare global with a different type", errors[1].msg, 1, true)
         assert.same(#unknowns, 0)
      end)
   end)

end)
