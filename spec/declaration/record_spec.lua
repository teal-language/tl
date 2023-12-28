local util = require("spec.util")

local function array(i, arr, not_arr)
   if i == 2 or i == 4 then
      return arr .. "\n"
   else
      return (not_arr or "") .. "\n"
   end
end

for i, name in ipairs({"records", "arrayrecords", "interfaces", "arrayinterfaces"}) do
   local statement = select(i, "record", "record", "interface", "interface")
   describe("#" .. name, function()
      it("can be declared with 'local type'", util.check([[
         local type Point = ]]..statement..[[ ]]..array(i, "{Point}")..[[
            x: number
            y: number
         end

         local p: Point = {}
         p.x = 12
         p.y = 12
      ]]))

      it("can be declared with 'local "..statement.."'", util.check([[
         local ]]..statement..[[ Point ]]..array(i, "{Point}")..[[
            x: number
            y: number
         end

         local p: Point = {}
         p.x = 12
         p.y = 12
      ]]))

      it("produces a nice error when declared with bare 'local'", util.check_syntax_error([[
         local Point = ]]..statement..[[ ]]..array(i, "{Point}")..[[
            x: number
            y: number
         end

         local p: Point = {}
         p.x = 12
         p.y = 12
      ]], {
         { y = 1, msg = "syntax error: this syntax is no longer valid; use 'local "..statement.." Point'" },
      }))

      it("produces a nice error when attempting to nest in a table", util.check_syntax_error([[
         local t = {
            Point = ]]..statement..[[ ]]..array(i, "{Point}")..[[
               x: number
               y: number
            end
         }
      ]], {
         { y = 2, msg = (statement == "interface"
                         and "syntax error: cannot declare interface inside a table; use a statement"
                         or  "syntax error: this syntax is no longer valid; declare nested record inside a record") },
      }))

      it("accepts "..statement.." as soft keyword", util.check([[
         local ]]..statement..[[ = 2
         local t = {
            ]]..statement..[[ = ]]..statement..[[,
         }
      ]]))

      it("can be declared with 'global type'", util.check([[
         global type Point = ]]..statement..[[ ]]..array(i, "{Point}")..[[
            x: number
            y: number
         end

         local p: Point = {}
         p.x = 12
         p.y = 12
      ]]))

      it("can be declared with 'global "..statement.."'", util.check([[
         global ]]..statement..[[ Point ]]..array(i, "{Point}")..[[
            x: number
            y: number
         end

         local p: Point = {}
         p.x = 12
         p.y = 12
      ]]))

      if statement == "interface" then
         it("can have self-references", util.check([[
            local interface SLAXML
               parse: function(self: SLAXML, xml: string, anotherself: SLAXML)
            end

            local myxml = io.open('my.xml'):read('*all')
            local slaxml: SLAXML = {}
            slaxml:parse(myxml, slaxml)
         ]]))
      else
         it("can have self-references", util.check([[
            local ]]..statement..[[ SLAXML ]]..array(i, "{SLAXML}")..[[
               parse: function(self: SLAXML, xml: string, anotherself: SLAXML)
            end

            local myxml = io.open('my.xml'):read('*all')
            SLAXML:parse(myxml, SLAXML)
         ]]))
      end

      it("can have circular type dependencies", util.check([[
         local type R = ]]..statement..[[ ]]..array(i, "{S}")..[[
            foo: S
         end

         local type S = ]]..statement..[[ ]]..array(i, "{R}")..[[
            foo: R
         end

         local function id(r: R): R
            return r
         end
      ]]))

      it("recursive types don't trip up the resolver", util.check([[
         local type EmptyString = enum "" end
         local ]]..statement..[[ ltn12 ]]..array(i, "{ltn12}")..[[
            type FancySource = function<T>(): T|EmptyString, string|FancySource<T>
         end
         return ltn12
      ]]))

      it("can overload functions", util.check([[
         global type love_graphics = ]]..statement..[[ ]]..array(i, "{love_graphics}")..[[
            print: function(text: string, x: number, y: number, r?: number, sx?: number, sy?: number, ox?: number, oy?: number, kx?: number, ky?: number)
            print: function(coloredtext: {any}, x: number, y: number, r?: number, sx?: number, sy?: number, ox?: number, oy?: number, kx?: number, ky?: number)
         end

         global type love = ]]..statement..[[ ]]..array(i, "{love}")..[[
            graphics: love_graphics
         end
      ]] .. (statement ~= "interface" and [[
         global function main()
            love.graphics.print("Hello world", 100, 100)
         end
      ]] or "")))

      it("cannot overload other things", util.check_syntax_error([[
         global type love_graphics = ]]..statement..[[ ]]..array(i, "{love_graphics}")..[[
            print: number
            print: string
         end
      ]], {
         { msg = "attempt to redeclare field 'print' (only functions can be overloaded)" }
      }))

      it("enum check in overloaded function", util.check_type_error([[
         local enum E
            "a"
            "b"
            "c"
         end
         local type R = ]]..statement..[[ ]]..array(i, "{number}")..[[
            f: function(enums: {E})
            f: function(tuple: {string, number})
         end
         local r: R
         r.f({"a", "b", "x"})
      ]], {
         { y = 11, msg = "argument 1: string \"x\" is not a member of E" }
      }))

      it("can report an error on unknown types in polymorphic definitions", util.check_type_error([[
         -- this reports an error
         local type R = ]]..statement..[[ ]]..array(i, "{R}")..[[
            u: function(): UnknownType
            u: function(): string
         end

         local function f(r: R): R
            return r
         end
      ]], {
         { y = 3, msg = "unknown type UnknownType"},
      }))

      it("can report an error on unknown types in polymorphic definitions in any order", util.check_type_error([[
         -- this reports an error
         local type R = ]]..statement..[[ ]]..array(i, "{R}")..[[
            u: function(): string
            u: function(): UnknownType
         end

         local function f(r: R): R
            return r
         end
      ]], {
         { y = 4, msg = "unknown type UnknownType"},
      }))

      it("can produce an intersection type for polymorphic functions", util.check([[
         local type requests = ]]..statement..[[ ]]..array(i, "{requests}")..[[

            type RequestOpts = ]]..statement..[[
               {string}
               url: string
            end

            type Response = ]]..statement..[[ ]]..array(i, "{Response}")..[[
               status_code: number
            end

            get: function(string): Response
            get: function(string, RequestOpts): Response
            get: function(RequestOpts): Response
         end

         local r: requests = {}
         local resp = r.get("hello")
      ]]))

      it("can check the arity of polymorphic functions", util.check_type_error([[
         local type requests = ]]..statement..[[ ]]..array(i, "{requests}")..[[

            type RequestOpts = ]]..statement..[[ --
               {string}
               url: string
            end

            type Response = ]]..statement..[[ ]]..array(i, "{Response}")..[[
               status_code: number
            end

            get: function(string): Response
            get: function(string, RequestOpts): Response
            get: function(RequestOpts): Response
         end

         local r: requests = {}
         local resp = r.get("hello", 123, 123)
      ]], {
        { y = 18, x = 28, msg = "wrong number of arguments (given 3, expects 1 or 2)" }
      }))

      it("can be nested", function()
         util.mock_io(finally, {
            ["req.d.tl"] = [[
               local type requests = record

                  type RequestOpts = ]]..statement..[[ --
                     {string}
                     url: string
                  end

                  type Response = ]]..statement..[[ ]]..array(i, "{Response}")..[[
                     status_code: number
                  end

                  get: function(string): Response
                  get: function(string, RequestOpts): Response
                  get: function(RequestOpts): Response
               end

               return requests
            ]],
         })
         util.run_check_type_error([[
            local req = require("req")

            local r = req.get("http://example.com")
            print(r.status_code)
            print(r.status_coda)
         ]], {
            { msg = (statement == "interface")
                    and "invalid key 'status_coda' in 'r' of interface type Response"
                    or  "invalid key 'status_coda' in record 'r' of type Response"
            }
         })
      end)

      it("can be nested with shorthand syntax", function()
         util.mock_io(finally, {
            ["req.d.tl"] = [[
               local type requests = record

                  ]]..statement..[[ RequestOpts
                     {string}
                     url: string
                  end

                  ]]..statement..[[ Response ]]..array(i, "{Response}")..[[
                     status_code: number
                  end

                  get: function(string): Response
                  get: function(string, RequestOpts): Response
                  get: function(RequestOpts): Response
               end

               return requests
            ]],
         })
         util.run_check_type_error([[
            local req = require("req")

            local r = req.get("http://example.com")
            print(r.status_code)
            print(r.status_coda)
         ]], {
            { msg = (statement == "interface")
                    and "invalid key 'status_coda' in 'r' of interface type Response"
                    or  "invalid key 'status_coda' in record 'r' of type Response"
            }
         })
      end)

      it(statement.." and enum and not reserved words", util.check([[
         local type foo = ]]..statement..[[ ]]..array(i, "{foo}")..[[
            ]]..statement..[[: string
            enum: number
         end

         local f: foo = {}

         f.]]..statement..[[ = "hello"
         f.enum = 123
      ]]))

      it("can have nested generic " .. name, util.check([[
         local type Foo = ]]..statement..[[ ]]..array(i, "{Foo}")..[[
            type Bar = ]]..statement..[[<T> ]]..array(i, "{Bar<T>}")..[[
               x: T
            end
            example: Bar<string>
         end

         local f: Foo = {}

         f.example = { x = "hello" }
      ]]))

      it("can have nested enums", util.check([[
         local type foo = ]]..statement..[[ ]]..array(i, "{foo}")..[[
            enum Direction
               "north"
               "south"
               "east"
               "west"
            end

            d: Direction
         end

         local f: foo = {}

         local dir: foo.Direction = "north"
         f.d = dir
      ]]))

      it("can have nested generic " .. name .. " with shorthand syntax", util.check([[
         local type foo = ]]..statement..[[ ]]..array(i, "{foo}")..[[
            ]]..statement..[[ bar<T> ]]..array(i, "{bar<T>}")..[[
               x: T
            end
            example: bar<string>
         end

         local f: foo = {}

         f.example = { x = "hello" }
      ]]))

      it("can mix nested "..statement.." syntax", util.check([[
         local type foo = ]]..statement..[[ ]]..array(i, "{foo}")..[[
            ]]..statement..[[ mid<T> ]]..array(i, "{mid<T>}")..[[
               type bar = ]]..statement..[[ ]]..array(i, "{bar}")..[[
                  x: T
               end
               z: bar
            end
            example: mid<string>
         end

         local f: foo = {}

         f.example = { z = { x = "hello" } }
      ]]))

      it("can have " .. name .. " in arrayrecords", util.check([[
         local ]]..statement..[[ bar ]]..array(i, "{bar}")..[[
         end
         local ]]..statement..[[ foo
            { bar }
         end
         local f : foo = { {  } }
      ]]))

      it("nested " .. name .. " in " .. name, util.check_type_error([[
         local ]]..statement..[[ foo ]]..array(i, "{foo}")..[[
            ]]..statement..[[ bar ]]..array(i, "{bar}")..[[
            end
         end
         local f : foo = { {  } }
      ]], {
         ({
            { msg = "in local declaration: f: got {{}} (inferred at foo.tl:5:26), expected foo" }, -- records
            nil, -- arrayrecords
            { msg = "in local declaration: f: got {{}} (inferred at foo.tl:5:26), expected foo" }, -- interfaces
            nil, -- interfaces with arrays
         })[i]
      }))

      it("can have nested enums in " .. name, util.check_type_error([[
         local ]]..statement..[[ foo ]]..array(i, "{bar}")..[[
            enum bar
               "baz"
            end
         end
         local f : foo = { "baz" }
      ]], {
         ({
            { msg = "in local declaration: f: got {string \"baz\"} (inferred at foo.tl:6:26), expected foo" }, -- records
            nil, -- arrayrecords
            { msg = "in local declaration: f: got {string \"baz\"} (inferred at foo.tl:6:26), expected foo" }, -- interfaces
            nil, -- interfaces with arrays
         })[i]
      }))

      it("can extend generic functions", util.check([[
         local type foo = ]]..statement..[[ ]]..array(i, "{foo}")..[[
            type bar = function<T>(T)
            example: bar<string>
         end

         function foo.example(data: string)
            print(data)
         end
      ]]))

      if statement == "record" then
         it("does not produce an esoteric type error (#167)", util.check_type_error([[
            local type foo = ]]..statement..[[ ]]..array(i, "{foo}")..[[
               type bar = function<T>(T)
               example: bar<string>
            end

            foo.example = function(data: string)
               print(data)
            end as bar<string>
         ]], {
            -- this is expected, because bar is local to foo
            { y = 8, x = 20, msg = "unknown type bar<string>" },
         }))
      else
         it("does not produce an esoteric type error (#167)", util.check_type_error([[
            local type foo = ]]..statement..[[ ]]..array(i, "{foo}")..[[
               type bar = function<T>(T)
               example: bar<string>
            end

            local f: foo = {}
            f.example = function(data: string)
               print(data)
            end as bar<string>
         ]], {
            -- this is expected, because bar is local to foo
            { y = 9, x = 20, msg = "unknown type bar<string>" },
         }))
      end

      it("can cast generic member using full path of type name", util.check([[
         local type foo = ]]..statement..[[ ]]..array(i, "{foo}")..[[
            type bar = function<T>(T)
            example: bar<string>
         end

         local f: foo = {}
         f.example = function(data: string)
            print(data)
         end as foo.bar<string>
      ]]))

      it("can export types as nested " .. name, function()
         util.mock_io(finally, {
            ["req.d.tl"] = [[
               local record requests

                  type RequestOpts = ]]..statement..[[
                     {string}
                     url: string
                  end

                  type Response = ]]..statement..[[ ]]..array(i, "{Response}")..[[
                     status_code: number
                  end

                  get: function(string): Response
                  get: function(string, RequestOpts): Response
                  get: function(RequestOpts): Response
               end

               return requests
            ]],
         })
         return util.check([[
            local req = require("req")

            local function f(): req.Response
               return req.get("http://example.com")
            end

            print(f().status_code)
         ]])()
      end)

      it("resolves aliasing of nested " .. name .. " (see #400)", util.check([[
         local ]]..statement..[[ Foo ]]..array(i, "{Foo}")..[[
            ]]..statement..[[ Bar ]]..array(i, "{Bar}")..[[
            end
         end
         local function func(_f: Foo.Bar) end

         local tab = { Foo = Foo }

         local x: tab.Foo.Bar
         func(x)
      ]]))

      it("resolves nested type aliases (see #416)", util.check([[
         local type A = number
         local ]]..statement..[[ Foo ]]..array(i, "{Foo}")..[[
            type B = A
         end

         local foo: Foo.B
         print(foo)
      ]]))

      it("resolves nested type aliases to other aliases (see #527)", util.check([[
         local ]]..statement..[[ M
            type Type1 = number
            type Type2 = Type1
         end

         local function map<E>(arr: {E}): {E: number}
         end

         local arr: {M.Type2} = {}
         local var: {M.Type2: number} = map(arr)
      ]]))

      it("can use nested type aliases as types (see #416)", util.check_type_error([[
         local ]]..statement..[[ F1 ]]..array(i, "{F1}")..[[
            ]]..statement..[[ A ]]..array(i, "{A}")..[[
               x: number
            end
            type C1 = A
            ]]..statement..[[ F2 ]]..array(i, "{F2}")..[[
               type C2 = C1
               ]]..statement..[[ F3 ]]..array(i, "{F3}")..[[
                  type C3 = C2
               end
            end
         end

         -- Let's use nested type aliases as types

         local foo: F1.F2.F3.C3 = {}
         foo.x = 123          -- correctly works
         foo.x = "hello"      -- correctly fails, with "got string, expected number"
      ]], {
         { y = 18, msg = 'got string "hello", expected number' },
      }))

      if statement == "record" then
         it("cannot use nested type aliases as values (see #416)", util.check_type_error([[
            local ]]..statement..[[ F1 ]]..array(i, "{F1}")..[[
               ]]..statement..[[ A ]]..array(i, "{C1}")..[[
                  x: number
               end
               type C1 = A
               ]]..statement..[[ F2 ]]..array(i, "{C2}")..[[
                  type C2 = C1
                  ]]..statement..[[ F3 ]]..array(i, "{C3}")..[[
                     type C3 = C2
                  end
               end
            end

            -- Let's use nested type aliases as prototypes

            F1.C1.x = 2

            local proto = F1.F2.F3.C3

            proto.x = 2
         ]], {
            { y = 16, msg = "cannot use a nested type alias as a concrete value" },
            { y = 20, msg = "cannot use a nested type alias as a concrete value" },
         }))
      else
         it("cannot use nested type aliases as values (see #416)", util.check_type_error([[
            local ]]..statement..[[ F1 ]]..array(i, "{F1}")..[[
               ]]..statement..[[ A ]]..array(i, "{C1}")..[[
                  x: number
               end
               type C1 = A
               ]]..statement..[[ F2 ]]..array(i, "{C2}")..[[
                  type C2 = C1
                  ]]..statement..[[ F3 ]]..array(i, "{C3}")..[[
                     type C3 = C2
                  end
               end
            end

            -- Let's use nested type aliases as prototypes

            F1.C1.x = 2

            local proto = F1.F2.F3.C3

            proto.x = 2
         ]], {
            { y = 16, msg = "interfaces are abstract" },
            { y = 16, msg = "cannot use a nested type alias as a concrete value" },
            { y = 18, msg = "interfaces are abstract" },
            { y = 18, msg = "interfaces are abstract" },
            { y = 18, msg = "interfaces are abstract" },
            { y = 20, msg = "cannot use a nested type alias as a concrete value" },
         }))
      end

      it("can resolve generics partially (see #417)", util.check_types([[
         local ]]..statement..[[ fun ]]..array(i, "{fun}")..[[
             ]]..statement..[[ iterator<T> ]]..array(i, "{iterator<T>}")..[[
                 reduce: function<R>(iterator<T>, (function(R, T): R), R): R
             end
             iter: function<T>({T}): iterator<T>
         end

         local f: fun

         local sum = f.iter({ 1, 2, 3, 4 }):reduce(function(a:integer,x:integer): integer
             return a + x
         end, 0)
      ]], {
         { y = 10, x = 16, type = "integer" },
      }))

      it("can have circular type dependencies on nested types", util.check([[
         local type R = ]]..statement..[[ ]]..array(i, "{S}")..[[
            type R2 = ]]..statement..[[ ]]..array(i, "{S.S2}")..[[
               foo: S.S2
            end

            foo: S
         end

         local type S = ]]..statement..[[ ]]..array(i, "{R}")..[[
            type S2 = ]]..statement..[[ ]]..array(i, "{R.R2}")..[[
               foo: R.R2
            end

            foo: R
         end

         local function id(r: R): R
            return r
         end
      ]]))

      it("can detect errors in type dependencies on nested types", util.check_type_error([[
         local ]]..statement..[[ R ]]..array(i, "{R}")..[[
            ]]..statement..[[ R2 ]]..array(i, "{R2}")..[[
               foo: S.S3
            end

            foo: S
         end

         local ]]..statement..[[ S ]]..array(i, "{S}")..[[
            ]]..statement..[[ S2 ]]..array(i, "{S2}")..[[
               foo: R.R2
            end

            foo: R
         end

         local function id(r: R): R
            return r
         end
      ]], {
         { y = 3, msg = "unknown type S.S3" }
      }))

      it("can contain reserved words/arbitrary strings with ['table key syntax']", util.check([[
         local ]]..statement..[[ A ]]..array(i, "{A}")..[=[
            start: number
            ["end"]: number
            [" "]: string
            ['123']: table
            [ [[  "hi"  ]] ]: table
         end
      ]=]))

      it("can be declared as userdata", util.check([[
         local type foo = ]]..statement..[[ ]]..array(i, "{foo}")..[[
            userdata
            x: number
            y: number
         end
      ]]))

      it("cannot be declared as userdata twice", util.check_syntax_error([[
         local type foo = ]]..statement..[[ ]]..array(i, "{foo}")..[[
            userdata
            userdata
            x: number
            y: number
         end
      ]], {
         { msg = "duplicated 'userdata' declaration" },
      }))

      it("untyped attributes are not accepted (#381)", util.check_syntax_error([[
         local ]]..statement..[[ kons ]]..array(i, "{kons}")..[[
            any_identifier other_sequence
            aaa bbb
         end
         local k: kons = {}
         print(k)
      ]], {
         { msg = "syntax error: expected ':' for an attribute" },
         { msg = "syntax error: expected ':' for an attribute" },
         { msg = "syntax error: expected ':' for an attribute" },
         { msg = "syntax error: expected ':' for an attribute" },
      }))

      it("catches redeclaration of literal keys", util.check_type_error([[
         local ]]..statement..[[ Foo ]]..array(i, "{Foo}")..[[
            foo: string
            bar: boolean
         end
         local x: Foo = {
            foo = "hello",
            bar = true,
            foo = "wat",
         }
      ]], {
         { y = 8, msg = "redeclared key foo" }
      }))

      it("catches redeclaration of literal keys, bracket syntax", util.check_type_error([[
         local ]]..statement..[[ Foo ]]..array(i, "{Foo}")..[[
            foo: string
            bar: boolean
         end
         local x: Foo = {
            ["foo"] = "hello",
            ["bar"] = true,
            ["foo"] = "wat",
         }
      ]], {
         { y = 8, msg = "redeclared key foo" }
      }))

      if statement ~= "interface" then
         it("can use itself in a constructor (regression test for #422)", util.check([[
            local ]]..statement..[[ Foo ]]..array(i, "{number}")..[[
            end

            function Foo:new(): Foo
               return setmetatable({} as Foo, self as metatable<Foo>)
            end

            local foo = Foo:new()
         ]]))

         it("can use itself in a constructor with dot notation (regression test for #422)", util.check([[
            local ]]..statement..[[ Foo ]]..array(i, "{number}")..[[
            end

            function Foo.new(): Foo
               return setmetatable({}, Foo as metatable<Foo>)
            end

            local foo = Foo.new()
         ]]))
      end

      it("creation of userdata records should be disallowed (#460)", util.check_type_error([[
         local ]]..statement..[[ Foo ]]..array(i, "{number}")..[[
            userdata
            a: number
         end
         local foo: Foo = {}
         foo = { a = 1 }
         local function f(foo: Foo) end
         f({})
         f({ a = 2 })
         local bar: Foo
         foo = bar
         f(bar)
      ]], {
         { y = 5, msg = "in local declaration: foo: got {}, expected Foo" },
         { y = 6, msg = "in assignment: record is not a userdata" },
         { y = 8, msg = "argument 1: got {}, expected Foo" },
         { y = 9, msg = "argument 1: record is not a userdata" },
         nil
      }))

      it("reports error on unknown interfaces", util.check_type_error([[
         local ]]..statement..[[ Foo ]]..array(i, "is {number}, Bongo, Bingo", "is Bongo, Bingo")..[[
            userdata
            a: number
         end
      ]], {
         { y = 1, msg = "unknown type Bongo" },
         { y = 1, msg = "unknown type Bingo" },
      }))
   end)
end

describe("arrayrecord", function()
   it("can be declared with is", util.check([[
      local record R1
         is {string}

         x: number
      end

      local v: R1 = { x = 10 }
      v[1] = "hello"
   ]]))

   it("assigning to array produces no warnings", util.check_warnings([[
      local record R1
         {string}

         x: number
      end

      local v: R1 = { x = 10 }
      v[1] = "hello"

      local a: {string} = v
      print(a)
   ]], {}))
end)

describe("abstract check", function()
   it("for nested interface", util.check_type_error([[
      local record F1
         interface F2
            z: number
         end
      end

      F1.F2.z = 9
   ]], {
      { y = 7, x = 9, msg = "interfaces are abstract", }
   }))
end)
