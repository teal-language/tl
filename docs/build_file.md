# build.tl file
Teal has the ability to run a custom function at compile time. The file containing this function is by default called `build.tl` but the name can be changed by setting `build_file` in `tlconfig.lua`.

This function can be used to automatically generate code/types without the need for external build tools like `make`. 

The results of executing this function are cached, and the cache is automatically made invalid if the build script changed since last execution. 
## Layout

A build.tl file needs at least the following layout:
```lua
return {
    gen_code = function(path:string)

    end
}
```
`gen_code` is the function that will get executed and `path` is the base path where it should store generated teal files.

More keys are planned in the future, which is why the file returns a table rather than it being executed directly.

## Output location

The teal files get stored in a temporary directory cleaned up after compilation (`/tmp` on Unix, `%TEMP%` on Windows). The generated teal files will get compiled to lua as normal and will be part of the build output.

You can configure where the lua files will be saved by setting `build_file_output_dir` in `tlconfig.lua`. This uses the directory set by `build_dir` as a base. The default value is `generated_code`.

## Use case

As mentioned earlier, this file can be used to generate types without the need for `make` or other external build tools. A reason why you might is if your teal code consumes an API that has schemas available.

Then you could simply add these schemas to your repo and have the `build.tl` file create types based on these schemas for you. That way you only need to grab a new version of the schemas if they change.

Another use case could be when using a teal version of a library like [pgtyped](https://github.com/adelsz/pgtyped) where you normally need to run a command manually to generate the types and code. Now you can just stick that in the `build.tl` file and forget about it.

## Limitations

Right now the `build.tl` file is mostly useful for programs and less for libraries. This is because `teal` does not have its own package manager able to run the `build.tl` files from required dependencies.

## Example

```lua
return {
    gen_code = function(path:string) 
        local file = io.open(path .. "/generated.tl", "w")
        file:write([[
function add(a : number, b : number): number
    return a + b
end
]])
    end
}
```
