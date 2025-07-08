local record lfs

   enum FileMode
      "file"
      "directory"
      "link"
      "socket"
      "named pipe"
      "char device"
      "block device"
      "other"
   end

   interface Attributes
      dev: integer
      ino: integer
      mode: FileMode
      nlink: integer
      uid: integer
      gid: integer
      rdev: integer
      access: integer
      modification: integer
      change: integer
      size: integer
      permissions: string
      blocks: integer
      blksize: integer
   end

   interface SymlinkAttributes is Attributes
      target: string
   end

   enum AttributeSelInt
      "dev"
      "ino"
      "nlink"
      "uid"
      "gid"
      "rdev"
      "access"
      "modification"
      "change"
      "size"
      "blocks"
      "blksize"
   end

   enum AttributeSelStr
      "permissions"
   end

   enum AttributeSelFM
      "mode"
   end

   enum OpenFileMode
      "binary"
      "text"
   end

   enum LockMode
      "r"
      "w"
   end

   record Lock
      free: function(self)
   end

   record DirObj
      next: function(self): string
      close: function(self)
   end

   dir: function(string): function(DirObj): (string), DirObj, nil, DirObj

   chdir: function(string): boolean, string

   lock_dir: function(string, ? integer): Lock, string

   link: function(string, string, ? boolean): boolean, string

   mkdir: function(string): boolean, string, integer

   rmdir: function(string): boolean, string, integer

   setmode: function(string, OpenFileMode): boolean, string

   currentdir: function(): string, string

   attributes: function(string): Attributes, string, integer
   attributes: function(string, AttributeSelStr): string, string, integer
   attributes: function(string, AttributeSelInt): integer, string, integer
   attributes: function(string, AttributeSelFM): FileMode, string, integer
   attributes: function(string, Attributes): Attributes, string, integer

   symlinkattributes: function(string): SymlinkAttributes, string, integer
   symlinkattributes: function(string, AttributeSelStr): string, string, integer
   symlinkattributes: function(string, AttributeSelInt): integer, string, integer
   symlinkattributes: function(string, AttributeSelFM): FileMode, string, integer
   symlinkattributes: function(string, SymlinkAttributes): SymlinkAttributes, string, integer

   touch: function(string, ? integer, ? integer): boolean, string

   -- TODO: FILE needs to be renamed to io.FILE in tl itself
   lock:   function(FILE, LockMode, ? integer, ? integer): boolean, string
   unlock: function(FILE,           ? integer, ? integer): boolean, string

end

return lfs
