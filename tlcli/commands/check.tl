--------------------------------------------------------------------------------
-- tl check
--------------------------------------------------------------------------------

local common = require("tlcli.common")
local driver = require("tlcli.driver")
local perf = require("tlcli.perf")
local report = require("tlcli.report")
local teal = require("teal.init")

local type Args = require("tlcli.args")
local type TlConfig = require("tlcli.tlconfig")
local type Compiler = teal.Compiler

local function split_drive(filename: string): string, string
   if common.sep == "\\" then
      local d, r = filename:match("^(.:)(.*)$")
      if d then
         return d, r
      end
   end
   return "", filename
end

local cd_cache: string
local function cd(): string
   if cd_cache then
      return cd_cache
   end
   local wd = os.getenv("PWD")
   if not wd then
      local pd = io.popen("cd", "r")
      wd = pd:read("*l")
      pd:close()
   end
   cd_cache = wd
   return wd
end

local function normalize(filename: string): string
   local drive = ""

   if common.sep == "\\" then
      filename = filename:gsub("\\", "/")
      drive, filename = split_drive(filename)
   end

   if filename:sub(1, 1) ~= "/" then
      filename = cd() .. "/" .. filename
      drive, filename = split_drive(filename)
   end

   local root = ""
   if filename:sub(1, 1) == "/" then
      root = "/"
   end

   local pieces = {}
   for piece in filename:gmatch("[^/]+") do
      if piece == ".." then
         local prev = pieces[#pieces]
         if not prev or prev == ".." then
            table.insert(pieces, "..")
         elseif prev ~= "" then
            table.remove(pieces)
         end
      elseif piece ~= "." then
         table.insert(pieces, piece)
      end
   end

   filename = (drive .. root .. table.concat(pieces, "/")):gsub("/*$", "")

   if common.sep == "\\" then
      filename = filename:gsub("/", "\\")
   end

   return filename
end

local function already_loaded(compiler: Compiler, input_file: string): boolean
   input_file = normalize(input_file)
   for file in compiler:loaded_files() do
      if normalize(file) == input_file then
         return true
      end
   end
   return false
end

return function(tlconfig: TlConfig, args: Args)
   perf.turbo(true)
   local compiler = driver.setup_compiler(tlconfig)
   for i, input_file in ipairs(args["file"]) do
      if not already_loaded(compiler, input_file) then
         local _, _, err = driver.process_module(compiler, input_file)
         if err then
            common.die(err)
         end
      end

      perf.check_collect(i)
   end

   local ok = report.report_all_errors(tlconfig, compiler)

   if ok and tlconfig["quiet"] == false and #args["file"] == 1 then
      local file_name = args["file"][1]

      local output_file = common.get_output_filename(file_name)
      print("========================================")
      print("Type checked " .. file_name)
      print("0 errors detected -- you can use:")
      print()
      print("   tl run " .. file_name)
      print()
      print("       to run " .. file_name .. " as a program")
      print()
      print("   tl gen " .. file_name)
      print()
      print("       to generate " .. output_file)
   end

   os.exit(ok and 0 or 1)
end
