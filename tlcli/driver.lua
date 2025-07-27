local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local os = _tl_compat and _tl_compat.os or os; local package = _tl_compat and _tl_compat.package or package; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table




local common = require("tlcli.common")
local teal = require("teal.init")


local driver = {}


local function filename_to_module_name(filename)
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


   return (filename:gsub("%.lua$", ""):gsub("%.d%.tl$", ""):gsub("%.tl$", ""):gsub("[/\\]", "."))
end

function driver.setup_compiler(tlconfig)
   tlconfig._init_env_modules = tlconfig._init_env_modules or {}
   if tlconfig.global_env_def then
      table.insert(tlconfig._init_env_modules, 1, tlconfig.global_env_def)
   end

   local opts = {
      feat_arity = tlconfig["feat_arity"],
      gen_compat = tlconfig["gen_compat"],
      gen_target = tlconfig["gen_target"],
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

local function already_loaded(compiler, input_file)
   input_file = common.normalize(input_file)
   for file in compiler:loaded_files() do
      if common.normalize(file) == input_file then
         return compiler:recall(file)
      end
   end
end

function driver.process_module(compiler, filename)
   local module, check_err = already_loaded(compiler, filename)
   if module then
      return module, check_err
   end

   local is_stdin = filename == "-"
   local module_name
   local input
   local err

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
