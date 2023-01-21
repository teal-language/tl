local util = require("spec.util")

describe("io", function()

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

      it("with a format argument", util.check([[
         for c in io.lines("filename.txt", 1) do
            print(c:upper())
         end
      ]]))

      it("with multiple formats", util.check([[
         for a, b in io.lines("filename.txt", "l", 12) do
            print(a:upper())
            print(b:upper())
         end
      ]]))

      pending("resolves the type of numeric formats", util.check([[
         for a, b in io.lines("filename.txt", "n", 12) do
            print(n * 2)
            print(b:upper())
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
            local function loadFile(textFile: string, amount: string | number): string, FILE
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
      end)

      describe("lines", function()
         it("with no arguments", util.check([[
            for l in io.popen("ls"):lines() do
               print(l:upper())
            end
         ]]))

         it("with a filename argument", util.check([[
            for l in io.popen("ls"):lines("filename.txt") do
               print(l:upper())
            end
         ]]))

         it("with a format argument", util.check([[
            for c in io.popen("ls"):lines("filename.txt", 1) do
               print(c:upper())
            end
         ]]))

         it("with multiple formats", util.check([[
            for a, b, c in io.popen("ls"):lines("filename.txt", "l", 12, 13) do
               print(a:upper())
               print(b:upper())
               print(c:upper())
            end
         ]]))

         pending("resolves the type of numeric formats", util.check([[
            for a, b in io.popen("ls"):lines("filename.txt", "n", 12) do
               print(n * 2)
               print(b:upper())
            end
         ]]))
      end)
   end)

end)
