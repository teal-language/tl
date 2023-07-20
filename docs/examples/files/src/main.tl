-- files/src/main.tl
-- Reads content from STDIN or file;
-- writes content in uppercase to STDOUT or file.
-------------------------------------------------------------------------------

-- record to hold file handles
local record Handles
   input: FILE
   output: FILE
end

-- a simple command-line parser
local function parse_arguments(args: {string}): string, string
   local i_name, o_name: string, string
   local err: string
   local i = 1
   while i <= #args do
      local a, b = args[i], args[i+1]
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
         -- exit, giving a hint on the way out
         error(err)
      end
   end
   return i_name, o_name
end

-- create or return file handles
local function get_fd(name: string, mode: string, default: FILE): FILE, string
   if not name then
      return default
   end

   local fd, err = io.open(name, mode)
   if not fd then
      return nil, err
   end

   return fd
end

-- get handles record
local function get_handles(input_name: string, output_name: string): Handles
   local handles: Handles = {}
   local err: string

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

-- do some work using the file handles
local function process_handles(h: Handles)
   local lines = h.input:read("*a")
   h.input:close()

   -- simple example of doing work on the input:
   -- convert it to ASCII uppercase
   lines = lines:upper()

   h.output:write(lines)
   h.output:close()
end

local function main(args: {string}): integer
   local input_name, output_name = parse_arguments(args)

   local h = get_handles(input_name, output_name)

   process_handles(h)

   os.exit(0)
end

main(arg)
