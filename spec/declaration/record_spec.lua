local tl = require("tl")
local util = require("spec.util")

describe("records", function()
   it("can have self-references", util.check [[
      local SLAXML = record
          parse: function(self: SLAXML, xml: string, anotherself: SLAXML)
       end

      local myxml = io.open('my.xml'):read('*all')
      SLAXML:parse(myxml, SLAXML)
   ]])

   it("can have circular type dependencies", util.check [[
      local R = record
         foo: S
      end

      local S = record
         foo: R
      end

      function id(r: R): R
         return r
      end
   ]])

   it("can have circular type dependencies on nested types", util.check [[
      local R = record
         R2 = record
            foo: S.S2
         end

         foo: S
      end

      local S = record
         S2 = record
            foo: R.R2
         end

         foo: R
      end

      function id(r: R): R
         return r
      end
   ]])

   it("can detect errors in type dependencies on nested types", util.check_type_error([[
      local R = record
         R2 = record
            foo: S.S3
         end

         foo: S
      end

      local S = record
         S2 = record
            foo: R.R2
         end

         foo: R
      end

      function id(r: R): R
         return r
      end
   ]], {
      { y = 3, msg = "unknown type S.S3" }
   }))

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

   it("can report an error on unknown types in polymorphic definitions", util.check_type_error([[
      -- this reports an error
      local R = record
         u: function(): UnknownType
         u: function(): string
      end

      function f(r: R): R
         return r
      end
   ]], {
      { y = 3, msg = "unknown type UnknownType"},
   }))

   it("can report an error on unknown types in polymorphic definitions in any order", util.check_type_error([[
      -- this reports an error
      local R = record
         u: function(): string
         u: function(): UnknownType
      end

      function f(r: R): R
         return r
      end
   ]], {
      { y = 4, msg = "unknown type UnknownType"},
   }))

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
      assert.same("invalid key 'status_coda' in record 'r' of type Response", result.type_errors[1].msg)
   end)

   it("can have nested generic records", util.check [[
      local foo = record
         bar = record<T>
            x: T
         end
         example: bar<string>
      end

      local f: foo = {}

      foo.example = { x = "hello" }
   ]])

   it("can extend generic functions", util.check [[
      local foo = record
         bar = functiontype<T>(T)
         example: bar<string>
      end

      function foo.example(data: string)
         print(data)
      end
   ]])

   it("does not produce an esoteric type error (#167)", util.check_type_error([[
      local foo = record
         bar = functiontype<T>(T)
         example: bar<string>
      end

      foo.example = function(data: string)
         print(data)
      end as bar<string>
   ]], {
      -- this is expected, because bar is local to foo
      { y = 8, x = 14, msg = "unknown type bar<string>" },
   }))

   it("can cast generic member using full path of type name", util.check [[
      local foo = record
         bar = functiontype<T>(T)
         example: bar<string>
      end

      foo.example = function(data: string)
         print(data)
      end as foo.bar<string>
   ]])

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
