local record TlConfig
   disable_warnings: {string}
   include_dir: {string}
   feat_arity: string
   gen_target: string
   gen_compat: string
   global_env_def: string
   pretend: boolean
   quiet: boolean
   skip_compat53: boolean
   warning_error: {string}
   _init_env_modules: {string}
   _disabled_warnings_set: {string:boolean}
   _warning_errors_set: {string:boolean}
end

return TlConfig
