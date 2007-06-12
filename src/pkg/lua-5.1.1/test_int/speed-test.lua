--
-- SPEED-TEST.LUA
--
-- Usage:   lua speed-test.lua [N]
--
-- Tests integer, and general performance of Lua (intended to be run
-- on separate number configurations, using 'time' to get the timings)
--
-- Based on the Lua 5.1 'test/factorial.lua' code. 
--
local N= tonumber(arg[1]) or 10000

--
-- Detect the number type (for printouts)
--
if false then
  local a= 2^24   -- out of float integer range
  if a+1 == a then
    print "float (23 bit integer range):"
  else
    a= 2^32     -- out of int32 range
    if a+1 == a then
        print "float & int32 patch (32 bit integer range):"
    else
        print "double (with or without patch, cannot tell):"
    end
  end
end

-- traditional fixed-point operator from functional programming
Y = function (g)
      local a = function (f) return f(f) end
      return a(function (f)
                 return g(function (x)
                             local c=f(f)
                             return c(x)
                           end)
               end)
end

-- factorial without recursion
F = function (f)
      return function (n)
               if n == 0 then return 1
               else return n*f(n-1) end
             end
    end

factorial = Y(F)   -- factorial is the fixed point of F

for i=1,N do
    local pile=nil
    for j=0,16 do
        local v= factorial(j)
        pile= pile and pile*j or 1
        assert( v==pile )
    end
end
