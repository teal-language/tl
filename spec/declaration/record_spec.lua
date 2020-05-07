local tl = require("tl")
local util = require("spec.util")

describe("records", function()
   it("can overload functions", function()
      local tokens = tl.lex([[
         global love_graphics = record
            print: function(text: string, x: number, y: number, r: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky:number)
            print: function(coloredtext: {any}, x: number, y: number, r: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky:number)
         end

         global love = record
            graphics: love_graphics
         end

         function main()
            love.graphics.print("Hello world", 100, 100)
         end
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("cannot overload other things", function()
      local tokens = tl.lex([[
         global love_graphics = record
            print: number
            print: string
         end
      ]])
      local syntax_errors = {}
      local _, ast = tl.parse_program(tokens, syntax_errors)
      assert.same("attempt to redeclare field 'print' (only functions can be overloaded)", syntax_errors[1].msg)
   end)

   it("can produce an intersection type for polymorphic functions", util.check [[
      local requests = record

         RequestOpts = record
            {string}
            url: string
         end

         Response = record
            status_code: number
         end

         get: function(string): Response
         get: function(string, RequestOpts): Response
         get: function(RequestOpts): Response
      end

      local r: requests = {}
      local resp = r.get("hello")
   ]])

   it("can check the arity of polymorphic functions", util.check_type_error([[
      local requests = record

         RequestOpts = record
            {string}
            url: string
         end

         Response = record
            status_code: number
         end

         get: function(string): Response
         get: function(string, RequestOpts): Response
         get: function(RequestOpts): Response
      end

      local r: requests = {}
      local resp = r.get("hello", 123, 123)
   ]], {
     { y = 18, msg = "wrong number of arguments (given 3, expects 1 or 2)" }
   }))

   it("can be nested", function()
      util.mock_io(finally, {
         ["req.d.tl"] = [[
            local requests = record

               RequestOpts = record
                  {string}
                  url: string
               end

               Response = record
                  status_code: number
               end

               get: function(string): Response
               get: function(string, RequestOpts): Response
               get: function(RequestOpts): Response
            end

            return requests
         ]],
         ["use.tl"] = [[
            local req = require("req")

            local r = req.get("http://example.com")
            print(r.status_code)
            print(r.status_coda)
         ]],
      })
      local result, err = tl.process("use.tl")
      assert.same("invalid key 'status_coda' in record 'r'", result.type_errors[1].msg)
   end)

   it("can export types as nested records", function()
      util.mock_io(finally, {
         ["req.d.tl"] = [[
            local requests = record

               RequestOpts = record
                  {string}
                  url: string
               end

               Response = record
                  status_code: number
               end

               get: function(string): Response
               get: function(string, RequestOpts): Response
               get: function(RequestOpts): Response
            end

            return requests
         ]],
         ["use.tl"] = [[
            local req = require("req")

            local function f(): req.Response
               return req.get("http://example.com")
            end

            print(f().status_code)
         ]],
      })
      local result, err = tl.process("use.tl")
      assert.same(0, #result.syntax_errors)
      assert.same({}, result.type_errors)
   end)

end)
