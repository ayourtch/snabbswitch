module(...,package.seeall)

local ffi = require("ffi")
local memory = require("core.memory")
local freelist = require("core.freelist")
local lib = require("core.lib")
local C = ffi.C

require("core.packet_h")

max       = 10e5
allocated = 0
size      = 4096

buffers = freelist.new("struct buffer *", max)
buffer_t = ffi.typeof("struct buffer")
buffer_ptr_t = ffi.typeof("struct buffer *")

-- Return a ready-to-use buffer, or nil if none is available.
function allocate ()
   return freelist.remove(buffers) or new_buffer()
end

-- Return a newly created buffer, or nil if none can be created.
function new_buffer ()
   assert(allocated < max, "out of buffers")
   allocated = allocated + 1
   local pointer, physical, bytes = memory.dma_alloc(size)
   local b = lib.malloc("struct buffer")
   b.pointer, b.physical, b.size = pointer, physical, size
   return b
end

-- Free a buffer that is no longer in use.
function free (b)
   freelist.add(buffers, b)
end

-- Create buffers until at least N are ready for use.
-- This is a way to pay the cost of allocating buffer memory in advance.
function preallocate (n)
   while freelist.nfree(buffers) < n do free(new_buffer()) end
end

