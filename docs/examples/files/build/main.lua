local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local os = _tl_compat and _tl_compat.os or os; local string = _tl_compat and _tl_compat.string or string











local function parse_arguments(args)
   local i_name, o_name
   local err
   local i = 1
   while i <= #args do
      local a, b = args[i], args[i + 1]
      if a == "-i" then
         if not b then
            err = "-i name?"
         else
            i_name = b
            i = i + 2
         end
      elseif a == "-o" then
         if not b then
            err = "-o name?"
         else
            o_name = b
            i = i + 2
         end
      else
         err = "unknown arg: " .. a
      end
      if err then

         error(err)
      end
   end
   return i_name, o_name
end


local function get_fd(name, mode, default)
   if not name then
      return default
   end

   local fd, err = io.open(name, mode)
   if not fd then
      return nil, err
   end

   return fd
end


local function get_handles(input_name, output_name)
   local handles = {}
   local err

   handles.input, err = get_fd(input_name, "r", io.stdin)
   if err then
      error(err)
   end

   handles.output, err = get_fd(output_name, "w", io.stdout)
   if err then
      error(err)
   end

   return handles
end


local function process_handles(h)
   local lines = h.input:read("*a")
   h.input:close()



   lines = lines:upper()

   h.output:write(lines)
   h.output:close()
end

local function main(args)
   local input_name, output_name = parse_arguments(args)

   local h = get_handles(input_name, output_name)

   process_handles(h)

   os.exit(0)
end

main(arg)
