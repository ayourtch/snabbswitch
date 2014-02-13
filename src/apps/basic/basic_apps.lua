module(...,package.seeall)

local app = require("core.app")
local buffer = require("core.buffer")
local packet = require("core.packet")
local link_ring = require("core.link_ring")

--- # `Source` app: generate synthetic packets

Source = {}

function Source:new()
   return setmetatable({}, {__index=Source})
end

function Source:pull ()
   for _, o in ipairs(self.outputi) do
      for i = 1, math.min(1000, app.nwritable(o)) do
         local p = packet.allocate()
         packet.add_iovec(p, buffer.allocate(), 60)
         app.transmit(o, p)
      end
   end
end

--- # `Join` app: Merge multiple inputs onto one output

Join = {}

function Join:new()
   return setmetatable({}, {__index=Join})
end

function Join:push () 
   for _, inport in ipairs(self.inputi) do
      for _ = 1,math.min(app.nreadable(inport), app.nwritable(self.output.out)) do
         app.transmit(self.output.out, app.receive(inport))
      end
   end
end

--- ### `Split` app: Split multiple inputs across multiple outputs

-- For each input port, push packets onto outputs. When one output
-- becomes full then continue with the next.
Split = {}

function Split:new ()
   return setmetatable({}, {__index=Split})
end

function Split:push ()
   for _, i in ipairs(self.inputi) do
      for _, o in ipairs(self.outputi) do
         for _ = 1, math.min(app.nreadable(i), app.nwritable(o)) do
            app.transmit(o, app.receive(i))
         end
      end
   end
end

--- ### `Sink` app: Receive and discard packets

Sink = {}

function Sink:new ()
   return setmetatable({}, {__index=Sink})
end

function Sink:push ()
   for _, i in ipairs(self.inputi) do
      for _ = 1, app.nreadable(i) do
        local p = app.receive(i)
        assert(p.refcount == 1)
        packet.deref(p)
      end
   end
end

--- ### `Tee` app: Send inputs to all outputs

Tee = {}

function Tee:new ()
   return setmetatable({}, {__index=Tee})
end

function Tee:push ()
   noutputs = #self.outputi
   if noutputs > 0 then
      local maxoutput = link_ring.max
      for _, o in ipairs(self.outputi) do
         maxoutput = math.min(maxoutput, app.nwritable(o))
      end
      for _, i in ipairs(self.inputi) do
         for _ = 1, math.min(app.nreadable(i), maxoutput) do
            local p = app.receive(i)
            packet.ref(p, noutputs - 1)
            maxoutput = maxoutput - 1
            for _, o in ipairs(self.outputi) do
               app.transmit(o, p)
            end
         end
      end
   end
end

--- ### `Repeater` app: Send all received packets in a loop

Repeater = {}

function Repeater:new ()
   return setmetatable({index = 1, packets = {}},
                       {__index=Repeater})
end

function Repeater:push ()
   local i, o = self.input.input, self.output.output
   for _ = 1, app.nreadable(i) do
      local p = app.receive(i)
      packet.ref(p)
      table.insert(self.packets, p)
   end
   local npackets = #self.packets
   if npackets > 0 then
      for i = 1, app.nwritable(o) do
         assert(self.packets[self.index])
         app.transmit(o, self.packets[self.index])
         self.index = (self.index % npackets) + 1
      end
   end
end

--- ### `Buzz` app: Print a debug message when called

Buzz = {}

function Buzz:new ()
   return setmetatable({}, {__index=Buzz})
end

function Buzz:pull () print "bzzz pull" end
function Buzz:push () print "bzzz push" end


