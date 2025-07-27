--------------------------------------------------------------------------------
-- Drive the compiler with filenames given from CLI arguments
--------------------------------------------------------------------------------

local type TlConfig = require("tlcli.tlconfig")
local common = require("tlcli.common")
local teal = require("teal.init")
local type Compiler = teal.Compiler

local record driver
end

local function filename_to_module_name(filename: string): string
   local path = os.getenv("TL_PATH") or package.path
   for entry in path:gmatch("[^;]+") do
      entry = entry:gsub("%.", "%%.")
      local lua_pat = "^" .. entry:gsub("%?", ".+") .. "$"
      local d_tl_pat = lua_pat:gsub("%%.lua%$", "%%.d%%.tl$")
      local tl_pat = lua_pat:gsub("%%.lua%$", "%%.tl$")

      for _, pat in ipairs({ tl_pat, d_tl_pat, lua_pat }) do
         local cap = filename:match(pat)
         if cap then
            return (cap:gsub("[/\\]", "."))
         end
      end
   end

   -- fallback:
   return (filename:gsub("%.lua$", ""):gsub("%.d%.tl$", ""):gsub("%.tl$", ""):gsub("[/\\]", "."))
end

function driver.setup_compiler(tlconfig: TlConfig): teal.Compiler
   tlconfig._init_env_modules = tlconfig._init_env_modules or {}
   if tlconfig.global_env_def then
      table.insert(tlconfig._init_env_modules, 1, tlconfig.global_env_def)
   end

   local opts: teal.CompilerOptions = {
      feat_arity = tlconfig["feat_arity"] as teal.Feat,
      gen_compat = tlconfig["gen_compat"] as teal.GenCompat,
      gen_target = tlconfig["gen_target"] as teal.GenTarget,
   }

   if opts.gen_target == "5.4" and opts.gen_compat ~= "off" then
      common.die("gen-compat must be explicitly 'off' when gen-target is '5.4'")
   end

   local compiler = teal.compiler(opts)

   for _, name in ipairs(tlconfig._init_env_modules) do
      local _, _, err = compiler:require(name)
      if err then
         common.die("Error: " .. err)
      end
   end

   return compiler
end

local function already_loaded(compiler: Compiler, input_file: string): teal.Module, teal.CheckError
   input_file = common.normalize(input_file)
   for file in compiler:loaded_files() do
      if common.normalize(file) == input_file then
         return compiler:recall(file)
      end
   end
end

function driver.process_module(compiler: Compiler, filename: string): teal.Module, teal.CheckError, string
   local module, check_err = already_loaded(compiler, filename)
   if module then
      return module, check_err
   end

   local is_stdin = filename == "-"
   local module_name: string
   local input: teal.Input
   local err: string

   if is_stdin then
      module_name = "stdin"
      input, err = compiler:input(io.input():read("*a"), "<stdin>")
   else
      module_name = filename_to_module_name(filename)
      input, err = compiler:open(filename)
   end
   if err then
      return nil, nil, err
   end

   return input:check(module_name)
end

return driver
