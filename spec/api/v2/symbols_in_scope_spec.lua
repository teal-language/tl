local tl = require("teal.api.v2")

local function resolve_type_ref(tr, type_number)
   local type_info = tr.types[type_number]
   if type_info and type_info.ref then
      return resolve_type_ref(tr, type_info.ref)
   else
      return type_info
   end
end

local DUMMY_FILENAME = "test"

local function assert_scope(tr)
   local symbols = tr.symbols_by_file[DUMMY_FILENAME]

   local scope_level = 0

   for _, s in ipairs(symbols) do
      if s[3] == "@{" then
         scope_level = scope_level + 1
      elseif s[3] == "@}" then
         scope_level = scope_level - 1
         assert(scope_level >= 0, "scope went below 0")
      end
   end

   assert(scope_level == 0, "scope is non-zero at end")
end

local function assert_types(tr, type_locations)
   for _, location in ipairs(type_locations) do
      local scoped = tl.symbols_in_scope(tr, location.line, 0, DUMMY_FILENAME)
      local scoped_type = assert(scoped[location.name] or tr.globals[location.name], "no type data found for " .. location.name .. " at line " .. tostring(location.line))
      local type_info = resolve_type_ref(tr, scoped_type)
      assert(type_info.str == location.type, "invalid type " .. type_info.str .. " at line " .. tostring(location.line) .. ", expected " .. location.type)
   end
end

local function assert_scope_and_types(sample_code, type_locations)
   local env = assert(tl.new_env())
   env.report_types = true

   tl.check_string(sample_code, env, DUMMY_FILENAME)

   local tr = env.reporter.tr

   assert_scope(tr)

   assert_types(tr, type_locations)
end

describe("blocks", function()
   it("multiple shadowing", function ()
      assert_scope_and_types([[
         local self = ""
         local a = ""

         local record rec1
            a: string
         end

         function rec1:one_method()
            local a = false
            print(self)
            print(a)
         end

         print(self)
         print(a)

         local record rec2
            a: string
         end

         function rec2:other_method()
            local a = {}
            print(self)
            print(a)
         end

         print(self)
         print(a)
      ]], {
         { line = 4,  name = "self", type = "string" },
         { line = 4,  name = "a",    type = "string" },

         { line = 11,  name = "self", type = "rec1" },
         { line = 11,  name = "a",    type = "boolean" },

         { line = 15,  name = "self", type = "string" },
         { line = 15,  name = "a",    type = "string" },

         { line = 24,  name = "self", type = "rec2" },
         { line = 24,  name = "a",    type = "{}" },

         { line = 27,  name = "self", type = "string" },
         { line = 27,  name = "a",    type = "string" },
      })
   end)

   it("forin", function ()
      assert_scope_and_types([[
         local tbl = {"one", "two", "three"}
         for i, v in ipairs(tbl) do
            local b = 1
         end
      ]], {
         { line = 4,  name = "i", type = "integer" },
         { line = 4,  name = "v", type = "string" },
         { line = 4,  name = "b", type = "integer" },
      })
   end)

   it("fornum", function ()
      assert_scope_and_types([[
         for i=1, 100 do
            local b = 1
         end
      ]], {
         { line = 3,  name = "i", type = "integer" },
         { line = 3,  name = "b", type = "integer" },
      })
   end)

   it("table literal with function", function()
      assert_scope_and_types([[
         local f = {
            func = function(n: integer)
               return n + 1
            end
         }

         print(f.func(1))
      ]], {
         { line = 4,  name = "n", type = "integer" },
      })
   end)

   it("record method with shadowing", function ()
      assert_scope_and_types([[
         local record test
            a: string
         end

         local b = false

         function record:method()
            local b = 1
         end
      ]], {
         { line = 8,  name = "b", type = "boolean" },
         { line = 9,  name = "b", type = "integer" },
         { line = 10, name = "b", type = "boolean" },
      })
   end)

   it("nested shadowing", function ()
      assert_scope_and_types([[
         local a: string = "starting"

         if a == "starting" then
            local a: integer = 1
            if a == 1 then
               local a = {}
            end
         end

         print(a)
      ]], {
         { line = 2, name = "a", type = "string" },
         { line = 5, name = "a", type = "integer" },
         { line = 7, name = "a", type = "{}" },
         { line = 8, name = "a", type = "integer" },
         { line = 10, name = "a", type = "string" },
      })
   end)

   it("self shadowing", function ()
      assert_scope_and_types([[
         local record r1 end

         function r1:method()
            local record r2 end
            function r2:method2()
               print(self)
            end
         end
      ]], {
         { line = 5, name = "self", type = "r1" },
         { line = 7, name = "self", type = "r2" },
         { line = 8, name = "self", type = "r1" },
      })
   end)
end)
