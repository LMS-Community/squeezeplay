local thread = require"thread"
local socket = require"socket"
local output = thread.newmutex()

function flood(word)
    for i = 1, tonumber(arg[1]) do
        output:lock()
        io.write(word, "\n")
        output:unlock()
        socket.sleep(0.01)
    end
end

for i = 1, tonumber(arg[1]) do
    thread.newthread(flood, {"child" .. i})
end

flood("parent")
