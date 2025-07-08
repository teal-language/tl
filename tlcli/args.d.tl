local record Args
   check: boolean
   command: string
   custom_ext: string
   feat_arity: string
   file: {string}
   gen_target: string
   gen_compat: string
   global_env_def: {string} -- FIXME should be `string`, but argparse can't handle `:count("0-1")`?...
   include_dir: {string}
   keep_hashbang: boolean
   output: string
   output_dir: string
   position: string
   pretend: boolean
   root: string
   quiet: boolean
   require: {string}
   script: {string}
   version: boolean
   wdisable: {string}
   werror: {string}
end

return Args
