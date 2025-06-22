local attributes = require("teal.attributes")


local types = require("teal.types")



local parser = require("teal.parser")


local variables = { Variable = {}, Scope = {} }




































function variables.has_var_been_used(var)
   return var.has_been_read_from or var.has_been_written_to
end

return variables
