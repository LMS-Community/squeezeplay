local thread = require("thread")
local metat = { __index = {} }
local setmetatable = setmetatable
module("thread.queue")

function metat.__index:insert(value)
    self.mutex:lock()
    while self.last - self.first >= self.size do
        self.notfull:wait(self.mutex)
    end
    local wasempty = (self.first == self.last)
    self[self.last] =  value
    self.last = self.last + 1
    if wasempty then self.notempty:signal() end
    self.mutex:unlock()
end

function metat.__index:remove()
    self.mutex:lock()
    while self.first == self.last do 
        self.notempty:wait(self.mutex) 
    end
    local value = self[self.first]
    local wasfull = (self.last - self.first >= self.size)
    self[self.first] = nil
    self.first = self.first + 1
    if wasfull then self.notfull:signal() end
    self.mutex:unlock()
    return value
end

function newqueue(size)
    local q = {
        mutex = thread.newmutex(), 
        notempty = thread.newcond(), 
        notfull = thread.newcond(), 
        first = 0, 
        last = 0,
        size = size
    }    
    return setmetatable(q, metat)
end
