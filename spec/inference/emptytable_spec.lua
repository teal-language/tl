local util = require("spec.util")

describe("empty table without type annotation", function()
   it("an empty return produces no type information (regression test for #234)", util.check_type_error([[
      local function heyyyy()
      end

      local ret_value = {heyyyy()}
      table.unpack(ret_value)
   ]], {
      { msg = "cannot determine type of tuple elements" },
   }))

   it("has its type determined by its first use", util.check_type_error([[
      local t = {}
      for i = 1, 10 do
         t[i] = i * 10
      end

      t.foo = "bar"
   ]], {
      { msg = [[cannot index key 'foo' in array 't' of type {integer} (inferred at foo.tl:3:11)]] },
   }))

   it("first use can be a function call", util.check([[
      local files = {}
      local pd = io.popen("git diff-tree -r HEAD", "r")
      for line in pd:lines() do
         local mode, file = line:match("^[^%s]+ [^%s]+ [^%s]+ [^%s]+ (.)\t(.-)$")
         if mode and file then
            table.insert(files, { mode = mode, file = file })
         end
      end

      for i, f in ipairs(files) do
         print(f.mode, f.file)
      end
   ]]))

   it("has its type determined by its first reassignment", util.check([[
      local function return_arr(): {number}
         local t = {}
         local arr = {1,2,3}
         if 2 < 3 then
            t = arr
         end
         return t
      end
   ]]))

   it("cannot be reassigned to a non-table", util.check_type_error([[
      local function return_arr(): {number}
         local t = {}
         local arr = {1,2,3}
         if 2 < 3 then
            t = 12
         end
         return t
      end
   ]], {
      { msg = "assigning integer to a variable declared with {}" },
   }))

   it("preserves provenance information", util.check_type_error([[
      local function return_arr(): {number}
         local t = {}
         local arr = {1,2,3}
         if 2 < 3 then
            t = arr
         end
         t.foo = "bar"
         return t
      end
   ]], {
      { msg = [[cannot index key 'foo' in array 't' of type {integer} (inferred at foo.tl:5:13)]] },
   }))

   it("inferred type is not const by default (#383)", util.check([[
      local negatives = {}
      negatives[1] = 1
      negatives = {}
   ]]))

   it("infers table keys to their nominal types, not their resolved types", util.check([[
      -- reduced from regression spotted by @catwell:
      -- https://github.com/teal-language/tl/pull/406#issuecomment-797763158

      local type Color = string

      local record BagData
         count: number
         color: Color
      end

      local type DirectGraph = {Color:{BagData}}

      local function parse_line(_line: string) : Color, {BagData}
          return "teal", {} as {BagData}
      end

      local M = {}

      function M.parse_input() : DirectGraph
          local r = {}
          local lines = {"a", "b"}
          for _, line in ipairs(lines) do
              local color, data = parse_line(line)
              r[color] = data
          end
          return r
      end

      return M
   ]]))

   it("emptytable does not infer as a union, but rather its first table-like element", util.check([[
      local record Foo<T>
      end
      local function foo<U>(x: U | Foo<U>)
      end
      foo({})

      -- non-inferred unions are ok
      local function foo2<U>(x: U | Foo<U>)
      end
      local z: number | Foo<number>
      foo2(z)
   ]]))

   it("map keys are unary", util.check([[
      local t = {}
      for i = 2, 254 do
         t[string.char(i)] = string.char(i + 1)
      end

      print(("hal"):gsub(".", t))
   ]]))

   it("does not get confused by flow-types in 'exp or {}' (regression test for #554)", util.check([[
      local function ivalues<Value>(t: {any:Value}): function(): Value
         local i = 0
         return function(): Value
            i = i + 1
            return t[i]
         end
      end

      local list: {string}
      for x in ivalues(list or {}) do
         print(x)
      end
   ]]))
end)
