local util = require("spec.util")

describe("io", function()

   describe("read", function()
      it("with no arguments", util.check([[
         local l = io.read()
         print(l:upper())
      ]]))

      it("with a bytes format argument", util.check([[
         local l = io.read(100)
         print(l:upper())
      ]]))

      it("with a string format argument", util.check([[
         local l = io.read("*a")
         print(l:upper())
      ]]))

      it("with a numeric format", util.check([[
         local n = io.read("n")
         print(n * 2)
         local m = io.read("*n")
         print(n + m)
      ]]))

      it("with multiple formats", util.check([[
         local a, b, c = io.read("l", 12, 13)
         print(a:upper())
         print(b:upper())
         print(c:upper())
      ]]))

      it("resolves the type of mixed numeric/string formats as unions for now", util.check([[
         local a, b = io.read("n", 12, 13)
         if a is number then
            print(a * 2)
         end
         if b is string then
            print(b:upper())
         end
      ]]))
   end)

   describe("lines", function()
      it("with no arguments", util.check([[
         for l in io.lines() do
            print(l:upper())
         end
      ]]))

      it("with a filename argument", util.check([[
         for l in io.lines("filename.txt") do
            print(l:upper())
         end
      ]]))

      it("with a bytes format argument", util.check([[
         for c in io.lines("filename.txt", 1) do
            print(c:upper())
         end
      ]]))

      it("with a string format argument", util.check([[
         for c in io.lines("filename.txt", "*l") do
            print(c:upper())
         end
      ]]))

      it("with multiple string formats", util.check([[
         for a, b in io.lines("filename.txt", "l", 12) do
            print(a:upper())
            print(b:upper())
         end
      ]]))

      it("with a numeric format", util.check([[
         for a in io.lines("n") do
            print(a * 2)
         end

         for a in io.lines("*n") do
            print(a * 2)
         end
      ]]))

      it("resolves the type of mixed numeric/string formats as unions for now", util.check([[
         for a, b in io.lines("n", 12) do
            if a is number then
               print(a * 2)
            end
            if b is string then
               print(b:upper())
            end
         end
      ]]))
   end)

   describe("FILE", function()
      it("is userdata", util.check([[
         local record R
            x: number
         end
         local fd = io.open("filename")
         local u: R | FILE
      ]]))

      describe("read", function()
         it("accepts a union (#317)", util.check([[
            local function loadFile(textFile: string, amount: string | integer): string, FILE
                local file = io.open(textFile, "r")
                if not file then error("ftcsv: File not found at " .. textFile) end
                local lines: string
                file:read(amount)
                if amount == "*all" then
                    file:close()
                end
                return lines, file
            end
         ]]))

         it("with no arguments", util.check([[
            local file = io.open("filename.txt")
            local l = file:read()
            print(l:upper())
         ]]))

         it("with a bytes format argument", util.check([[
            local file = io.open("filename.txt")
            local l = file:read(100)
            print(l:upper())
         ]]))

         it("with a string format argument", util.check([[
            local file = io.open("filename.txt")
            local l = file:read("*a")
            print(l:upper())
         ]]))

         it("with a numeric format", util.check([[
            local file = io.open("filename.txt")
            local n = file:read("n")
            print(n * 2)
            local m = file:read("*n")
            print(n + m)
         ]]))

         it("with multiple formats", util.check([[
            local file = io.open("filename.txt")
            local a, b, c = file:read("l", 12, 13)
            print(a:upper())
            print(b:upper())
            print(c:upper())
         ]]))

         it("resolves the type of mixed numeric/string formats as unions for now", util.check([[
            local file = io.open("filename.txt")
            local a, b = file:read("n", 12, 13)
            if a is number then
               print(a * 2)
            end
            if b is string then
               print(b:upper())
            end
         ]]))
      end)

      describe("lines", function()
         it("with no arguments", util.check([[
            for l in io.popen("ls"):lines() do
               print(l:upper())
            end
         ]]))

         it("with a bytes format argument", util.check([[
            for c in io.popen("ls"):lines("filename.txt", 1) do
               print(c:upper())
            end
         ]]))

         it("with a string format argument", util.check([[
            for c in io.popen("ls"):lines("*l") do
               print(c:upper())
            end
         ]]))

         it("with a numeric format", util.check([[
            for a in io.popen("ls"):lines("n") do
               print(a * 2)
            end

            for a in io.popen("ls"):lines("*n") do
               print(a * 2)
            end
         ]]))

         it("with multiple formats", util.check([[
            for a, b, c in io.popen("ls"):lines("filename.txt", "l", 12, 13) do
               print(a:upper())
               print(b:upper())
               print(c:upper())
            end
         ]]))

         it("resolves the type of mixed numeric/string formats as unions for now", util.check([[
            for a, b in io.popen("ls"):lines("n", 12) do
               if a is number then
                  print(a * 2)
               end
               if b is string then
                  print(b:upper())
               end
            end
         ]]))
      end)
   end)

end)
