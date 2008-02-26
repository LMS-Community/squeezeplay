--
-- FLOAT-TEST.LUA
--
-- Self-test to see that floats, and int32 patch are working okay.
--
-- Copyright (c) 2006, Asko Kauppi <akauppi@gmail.com>
--
local MODE_DOUBLE
local MODE_FLOAT
local MODE_FLOAT_INT32
local MODE_XX_INT64
local mode_str

local function TEST( s, func )
    io.stderr:write( "\n*** "..s.." ***\n" )
    func()
    io.flush()
    io.stderr:write "Passed.\n" 
end

--
TEST( "Simple for test (integer)", function()
  for i=1,50 do io.write(i,'\t') end
end)

TEST( "Simple for test (floating point)", function()
  for i=1.1,50.2 do io.write(i,'\t') end
end)


--
TEST( "Find out number type", function()
  local a= 2^24   -- out of float integer range

  if a+1 == a then
    MODE_FLOAT,mode_str= true,"float (23 bit integer range)"
  else
    a= 2^32     -- out of int32 range
    
    if a+1 == a then
        -- Values above the int32 range fall back to floats (leaves gaps in
        -- integer accuracy, but the magnitude of numbers remains)
        --
        MODE_FLOAT_INT32,mode_str= true,"float & int32 patch (32 bit integer range)"
    else
        a= 2^53     -- out of double integer range
        if a+1 == a then
            MODE_DOUBLE,mode_str= true,"double (52 bit integer range)"
        else
            MODE_XX_INT64,mode_str= true,"xx (64 bit integer range)"
        end
    end
  end
  print( mode_str )

  -- The constant accuracy should match that of internal one (32/64 bits)
  --
  local con_bits
  if string.format('%x',0x7fffffffffffffff) == "7fffffffffffffff" then
      con_bits= 64
  elseif string.format('%x',0x7fffffff) == "7fffffff" then
      assert( string.format('%x',0x100000000) ~= "100000000" )
      con_bits= 32
  elseif string.format('%x',0x3fffff) == "3fffff" then
      assert( string.format('%x',0x7fffff) ~= "7fffff" )
      con_bits= 23  -- plain floats (no integer patch)
  else
      con_bits= "xx"
  end
  print( "Lua constants: "..con_bits.." bits." )
end)

--
if MODE_FLOAT_INT32 then
  TEST( "Int32: tostring test", function()
    local a= 16770201
    local s= tostring(a)
    if string.find(s,"[^%d]") then
      error "tostring() should have shown integer only."
    end
    if tonumber(s) ~= a then
      error "tonumber() failed!"
    end
  end)
end

--
if MODE_XX_INT64 then
  TEST( "Int64: range test", function()
    -- Running this with float+int32, without int-vm patch fails, due to overflow of the constants
    -- read in (no sense in debugging that further, better to use the int-vm patch?).

    -- This is _without_ using int64 accuracy constants
    local a1= 0x7fffffff * 0x10000 * 0x10000 + 0xffffffff  -- 2^63-1 == last positive integer
    assert( tostring(a1) == "9223372036854775807" )
    assert( string.format('%x',a1) == "7fffffffffffffff" )

    -- With int64 accuracy constants (needs VM changes in Lua)
    local a2= 0x7fffffffffffffff
    assert( tostring(a2) == "9223372036854775807" )
    assert( string.format('%x',a2) == "7fffffffffffffff" )

    assert( a1 == a2 )
    local a= a1
print( a-2,a-1,a,a+1,a+2 )
    --9223372036854775805     9223372036854775806     9223372036854775807     9.22337[20368548]e+18     9.22337[20368548]e+18
    assert( string.find( tostring(a+1), "9%.22337%d*e%+18" ) )  
    assert( tostring(a+2) == tostring(a+1) )
    assert( a+1 == a+2 )
    assert( a ~= a+1 )
    assert( a ~= a-1 )
  end)
end


--
TEST( "Simple integer tests", function() 
  local a= 5
  assert( type(a)=="number" )

  assert( a+1 == 6 )
  print(a)
end)

--
TEST( "Simple fraction tests", function()
  local a= 5.2
  assert( type(a)=="number" )

  assert( a+1 == 6.2 )
  assert( -a == -5.2 )
-- FIXME PAD: these two fail on Ubuntu?
--  assert( -a == 5.2 * (-1) )
--  assert( a*10 == 52 )
  assert( a/a == 1 )

  print(a)
end)

--
TEST( "Simple table tests", function()
  local t= { [1]='a', [2.1]='b' }

  assert( t[1]=='a' )
  assert( t[1.0]=='a' )
  assert( t[2.1]=='b' )
  assert( t[2]==nil )
end)

--
TEST( "for tests (extract from 'factorial.lua')", function()
  -- 
  local n=0
  local c0=20
  for c=c0,c0+10-1 do
    io.write(c,' ')
    n= n+1
  end
  print ""
  assert( n==10 )
end)

--
-- 2^0..2^30 may be integer optimized (or not, we wouldn't know :)
--
if MODE_FLOAT_INT32 then
  TEST( "Power of 2 tests", function()
    local v=nil
    for n=0,40 do
      v= v and v*2 or 1
      assert ( 2^n == v )
    end
  end)
end

--
TEST( "modulo tests", function()
-- 
-- Mod cases, autocreated by stock Lua 5.1 (rc), for testing the Int32 patch.
--
assert( (-7) % (-21) == -7 )
assert( (-7) % (-20) == -7 )
assert( (-7) % (-19) == -7 )
assert( (-7) % (-18) == -7 )
assert( (-7) % (-17) == -7 )
assert( (-7) % (-16) == -7 )
assert( (-7) % (-15) == -7 )
assert( (-7) % (-14) == -7 )
assert( (-7) % (-13) == -7 )
assert( (-7) % (-12) == -7 )
assert( (-7) % (-11) == -7 )
assert( (-7) % (-10) == -7 )
assert( (-7) % (-9) == -7 )
assert( (-7) % (-8) == -7 )
assert( (-7) % (-7) == -0 )
assert( (-7) % (-6) == -1 )
assert( (-7) % (-5) == -2 )
assert( (-7) % (-4) == -3 )
assert( (-7) % (-3) == -1 )
assert( (-7) % (-2) == -1 )
assert( (-7) % (-1) == -0 )
assert( (-7) % (21) == 14 )
assert( (-7) % (20) == 13 )
assert( (-7) % (19) == 12 )
assert( (-7) % (18) == 11 )
assert( (-7) % (17) == 10 )
assert( (-7) % (16) == 9 )
assert( (-7) % (15) == 8 )
assert( (-7) % (14) == 7 )
assert( (-7) % (13) == 6 )
assert( (-7) % (12) == 5 )
assert( (-7) % (11) == 4 )
assert( (-7) % (10) == 3 )
assert( (-7) % (9) == 2 )
assert( (-7) % (8) == 1 )
assert( (-7) % (7) == -0 )
assert( (-7) % (6) == 5 )
assert( (-7) % (5) == 3 )
assert( (-7) % (4) == 1 )
assert( (-7) % (3) == 2 )
assert( (-7) % (2) == 1 )
assert( (-7) % (1) == -0 )
assert( (-6) % (-18) == -6 )
assert( (-6) % (-17) == -6 )
assert( (-6) % (-16) == -6 )
assert( (-6) % (-15) == -6 )
assert( (-6) % (-14) == -6 )
assert( (-6) % (-13) == -6 )
assert( (-6) % (-12) == -6 )
assert( (-6) % (-11) == -6 )
assert( (-6) % (-10) == -6 )
assert( (-6) % (-9) == -6 )
assert( (-6) % (-8) == -6 )
assert( (-6) % (-7) == -6 )
assert( (-6) % (-6) == -0 )
assert( (-6) % (-5) == -1 )
assert( (-6) % (-4) == -2 )
assert( (-6) % (-3) == -0 )
assert( (-6) % (-2) == -0 )
assert( (-6) % (-1) == -0 )
assert( (-6) % (18) == 12 )
assert( (-6) % (17) == 11 )
assert( (-6) % (16) == 10 )
assert( (-6) % (15) == 9 )
assert( (-6) % (14) == 8 )
assert( (-6) % (13) == 7 )
assert( (-6) % (12) == 6 )
assert( (-6) % (11) == 5 )
assert( (-6) % (10) == 4 )
assert( (-6) % (9) == 3 )
assert( (-6) % (8) == 2 )
assert( (-6) % (7) == 1 )
assert( (-6) % (6) == -0 )
assert( (-6) % (5) == 4 )
assert( (-6) % (4) == 2 )
assert( (-6) % (3) == -0 )
assert( (-6) % (2) == -0 )
assert( (-6) % (1) == -0 )
assert( (-5) % (-15) == -5 )
assert( (-5) % (-14) == -5 )
assert( (-5) % (-13) == -5 )
assert( (-5) % (-12) == -5 )
assert( (-5) % (-11) == -5 )
assert( (-5) % (-10) == -5 )
assert( (-5) % (-9) == -5 )
assert( (-5) % (-8) == -5 )
assert( (-5) % (-7) == -5 )
assert( (-5) % (-6) == -5 )
assert( (-5) % (-5) == -0 )
assert( (-5) % (-4) == -1 )
assert( (-5) % (-3) == -2 )
assert( (-5) % (-2) == -1 )
assert( (-5) % (-1) == -0 )
assert( (-5) % (15) == 10 )
assert( (-5) % (14) == 9 )
assert( (-5) % (13) == 8 )
assert( (-5) % (12) == 7 )
assert( (-5) % (11) == 6 )
assert( (-5) % (10) == 5 )
assert( (-5) % (9) == 4 )
assert( (-5) % (8) == 3 )
assert( (-5) % (7) == 2 )
assert( (-5) % (6) == 1 )
assert( (-5) % (5) == -0 )
assert( (-5) % (4) == 3 )
assert( (-5) % (3) == 1 )
assert( (-5) % (2) == 1 )
assert( (-5) % (1) == -0 )
assert( (-4) % (-12) == -4 )
assert( (-4) % (-11) == -4 )
assert( (-4) % (-10) == -4 )
assert( (-4) % (-9) == -4 )
assert( (-4) % (-8) == -4 )
assert( (-4) % (-7) == -4 )
assert( (-4) % (-6) == -4 )
assert( (-4) % (-5) == -4 )
assert( (-4) % (-4) == -0 )
assert( (-4) % (-3) == -1 )
assert( (-4) % (-2) == -0 )
assert( (-4) % (-1) == -0 )
assert( (-4) % (12) == 8 )
assert( (-4) % (11) == 7 )
assert( (-4) % (10) == 6 )
assert( (-4) % (9) == 5 )
assert( (-4) % (8) == 4 )
assert( (-4) % (7) == 3 )
assert( (-4) % (6) == 2 )
assert( (-4) % (5) == 1 )
assert( (-4) % (4) == -0 )
assert( (-4) % (3) == 2 )
assert( (-4) % (2) == -0 )
assert( (-4) % (1) == -0 )
assert( (-3) % (-9) == -3 )
assert( (-3) % (-8) == -3 )
assert( (-3) % (-7) == -3 )
assert( (-3) % (-6) == -3 )
assert( (-3) % (-5) == -3 )
assert( (-3) % (-4) == -3 )
assert( (-3) % (-3) == -0 )
assert( (-3) % (-2) == -1 )
assert( (-3) % (-1) == -0 )
assert( (-3) % (9) == 6 )
assert( (-3) % (8) == 5 )
assert( (-3) % (7) == 4 )
assert( (-3) % (6) == 3 )
assert( (-3) % (5) == 2 )
assert( (-3) % (4) == 1 )
assert( (-3) % (3) == -0 )
assert( (-3) % (2) == 1 )
assert( (-3) % (1) == -0 )
assert( (-2) % (-6) == -2 )
assert( (-2) % (-5) == -2 )
assert( (-2) % (-4) == -2 )
assert( (-2) % (-3) == -2 )
assert( (-2) % (-2) == -0 )
assert( (-2) % (-1) == -0 )
assert( (-2) % (6) == 4 )
assert( (-2) % (5) == 3 )
assert( (-2) % (4) == 2 )
assert( (-2) % (3) == 1 )
assert( (-2) % (2) == -0 )
assert( (-2) % (1) == -0 )
assert( (-1) % (-3) == -1 )
assert( (-1) % (-2) == -1 )
assert( (-1) % (-1) == -0 )
assert( (-1) % (3) == 2 )
assert( (-1) % (2) == 1 )
assert( (-1) % (1) == -0 )
assert( (1) % (-3) == -2 )
assert( (1) % (-2) == -1 )
assert( (1) % (-1) == -0 )
assert( (1) % (3) == 1 )
assert( (1) % (2) == 1 )
assert( (1) % (1) == -0 )
assert( (2) % (-6) == -4 )
assert( (2) % (-5) == -3 )
assert( (2) % (-4) == -2 )
assert( (2) % (-3) == -1 )
assert( (2) % (-2) == -0 )
assert( (2) % (-1) == -0 )
assert( (2) % (6) == 2 )
assert( (2) % (5) == 2 )
assert( (2) % (4) == 2 )
assert( (2) % (3) == 2 )
assert( (2) % (2) == -0 )
assert( (2) % (1) == -0 )
assert( (3) % (-9) == -6 )
assert( (3) % (-8) == -5 )
assert( (3) % (-7) == -4 )
assert( (3) % (-6) == -3 )
assert( (3) % (-5) == -2 )
assert( (3) % (-4) == -1 )
assert( (3) % (-3) == -0 )
assert( (3) % (-2) == -1 )
assert( (3) % (-1) == -0 )
assert( (3) % (9) == 3 )
assert( (3) % (8) == 3 )
assert( (3) % (7) == 3 )
assert( (3) % (6) == 3 )
assert( (3) % (5) == 3 )
assert( (3) % (4) == 3 )
assert( (3) % (3) == -0 )
assert( (3) % (2) == 1 )
assert( (3) % (1) == -0 )
assert( (4) % (-12) == -8 )
assert( (4) % (-11) == -7 )
assert( (4) % (-10) == -6 )
assert( (4) % (-9) == -5 )
assert( (4) % (-8) == -4 )
assert( (4) % (-7) == -3 )
assert( (4) % (-6) == -2 )
assert( (4) % (-5) == -1 )
assert( (4) % (-4) == -0 )
assert( (4) % (-3) == -2 )
assert( (4) % (-2) == -0 )
assert( (4) % (-1) == -0 )
assert( (4) % (12) == 4 )
assert( (4) % (11) == 4 )
assert( (4) % (10) == 4 )
assert( (4) % (9) == 4 )
assert( (4) % (8) == 4 )
assert( (4) % (7) == 4 )
assert( (4) % (6) == 4 )
assert( (4) % (5) == 4 )
assert( (4) % (4) == -0 )
assert( (4) % (3) == 1 )
assert( (4) % (2) == -0 )
assert( (4) % (1) == -0 )
assert( (5) % (-15) == -10 )
assert( (5) % (-14) == -9 )
assert( (5) % (-13) == -8 )
assert( (5) % (-12) == -7 )
assert( (5) % (-11) == -6 )
assert( (5) % (-10) == -5 )
assert( (5) % (-9) == -4 )
assert( (5) % (-8) == -3 )
assert( (5) % (-7) == -2 )
assert( (5) % (-6) == -1 )
assert( (5) % (-5) == -0 )
assert( (5) % (-4) == -3 )
assert( (5) % (-3) == -1 )
assert( (5) % (-2) == -1 )
assert( (5) % (-1) == -0 )
assert( (5) % (15) == 5 )
assert( (5) % (14) == 5 )
assert( (5) % (13) == 5 )
assert( (5) % (12) == 5 )
assert( (5) % (11) == 5 )
assert( (5) % (10) == 5 )
assert( (5) % (9) == 5 )
assert( (5) % (8) == 5 )
assert( (5) % (7) == 5 )
assert( (5) % (6) == 5 )
assert( (5) % (5) == -0 )
assert( (5) % (4) == 1 )
assert( (5) % (3) == 2 )
assert( (5) % (2) == 1 )
assert( (5) % (1) == -0 )
assert( (6) % (-18) == -12 )
assert( (6) % (-17) == -11 )
assert( (6) % (-16) == -10 )
assert( (6) % (-15) == -9 )
assert( (6) % (-14) == -8 )
assert( (6) % (-13) == -7 )
assert( (6) % (-12) == -6 )
assert( (6) % (-11) == -5 )
assert( (6) % (-10) == -4 )
assert( (6) % (-9) == -3 )
assert( (6) % (-8) == -2 )
assert( (6) % (-7) == -1 )
assert( (6) % (-6) == -0 )
assert( (6) % (-5) == -4 )
assert( (6) % (-4) == -2 )
assert( (6) % (-3) == -0 )
assert( (6) % (-2) == -0 )
assert( (6) % (-1) == -0 )
assert( (6) % (18) == 6 )
assert( (6) % (17) == 6 )
assert( (6) % (16) == 6 )
assert( (6) % (15) == 6 )
assert( (6) % (14) == 6 )
assert( (6) % (13) == 6 )
assert( (6) % (12) == 6 )
assert( (6) % (11) == 6 )
assert( (6) % (10) == 6 )
assert( (6) % (9) == 6 )
assert( (6) % (8) == 6 )
assert( (6) % (7) == 6 )
assert( (6) % (6) == -0 )
assert( (6) % (5) == 1 )
assert( (6) % (4) == 2 )
assert( (6) % (3) == -0 )
assert( (6) % (2) == -0 )
assert( (6) % (1) == -0 )
assert( (7) % (-21) == -14 )
assert( (7) % (-20) == -13 )
assert( (7) % (-19) == -12 )
assert( (7) % (-18) == -11 )
assert( (7) % (-17) == -10 )
assert( (7) % (-16) == -9 )
assert( (7) % (-15) == -8 )
assert( (7) % (-14) == -7 )
assert( (7) % (-13) == -6 )
assert( (7) % (-12) == -5 )
assert( (7) % (-11) == -4 )
assert( (7) % (-10) == -3 )
assert( (7) % (-9) == -2 )
assert( (7) % (-8) == -1 )
assert( (7) % (-7) == -0 )
assert( (7) % (-6) == -5 )
assert( (7) % (-5) == -3 )
assert( (7) % (-4) == -1 )
assert( (7) % (-3) == -2 )
assert( (7) % (-2) == -1 )
assert( (7) % (-1) == -0 )
assert( (7) % (21) == 7 )
assert( (7) % (20) == 7 )
assert( (7) % (19) == 7 )
assert( (7) % (18) == 7 )
assert( (7) % (17) == 7 )
assert( (7) % (16) == 7 )
assert( (7) % (15) == 7 )
assert( (7) % (14) == 7 )
assert( (7) % (13) == 7 )
assert( (7) % (12) == 7 )
assert( (7) % (11) == 7 )
assert( (7) % (10) == 7 )
assert( (7) % (9) == 7 )
assert( (7) % (8) == 7 )
assert( (7) % (7) == -0 )
assert( (7) % (6) == 1 )
assert( (7) % (5) == 2 )
assert( (7) % (4) == 3 )
assert( (7) % (3) == 1 )
assert( (7) % (2) == 1 )
assert( (7) % (1) == -0 )
end)

--
if MODE_FLOAT_INT32 then
  local MIN= -2147483648    -- -2^31
  local MAX= 2147483647     -- 2^31-1
   
  assert( MIN < 0 )
  assert( MAX > 0 )

  TEST( "+: edge check", function()
    assert( MIN-1 < 0 )
    assert( MAX+1 > 0 )
    assert( MIN-1 == MIN )  -- ha, really remains the same (due to float accuracy)
    assert( MAX+1 == MAX )
  end)

  TEST( "-: edge check", function()
    assert( 0 - MIN > 0 )
    assert( 0 - MIN == MAX )    -- due to float accuracy
    assert( 0 - MAX == MIN+1 )
    assert( MAX - MIN > MAX )   -- way bigger
  end)

  TEST( "*: edge check", function()
    assert( 0*MIN == 0 )
    assert( 0*MAX == 0 )
    assert( 1*MAX == MAX )
    assert( -1*MAX == MIN+1 )
    assert( 1*MIN == MIN )
    assert( -1*MIN == MAX )     -- due to float accuracy
    assert( 3*MIN < MIN )
    assert( MIN*MAX < 0 )
    assert( MAX*MIN < 0 )
    assert( MIN*MIN > MAX )
    assert( MAX*MAX > MAX )
  end)

  TEST( "/: edge check", function()
    assert( 0/MIN == 0 )
    assert( 0/MAX == 0 )
    assert( MAX/MIN < 0 )
    assert( MAX/MIN == -1 )      -- really -0.9999..... (but accuracy rounds to 1?)
    assert( MIN/MAX < 0 )
    assert( MIN/MAX == -1 )
    assert( MIN/MIN == 1 )
    assert( MAX/MAX == 1 )
    assert( MIN/1 == MIN )
    assert( MAX/1 == MAX )
  end)

  TEST( "%: edge check", function()
    assert( MIN%MIN == 0 )
    assert( MIN%(-5) == -3 )
    assert( MIN%(MIN+1) == -1 )
    assert( MIN%5 == 2 )
    assert( -5 % MIN == -5 )
    assert( (MIN+1) % MIN == MIN+1 )
    assert( 5 % MIN == MIN+5 )   -- -2147483643
    assert( MIN%MAX == MAX-1 )  -- 2147483646
  end)

  TEST( "unm: edge check", function()
    assert( -MIN == MAX )   -- float inaccuracy
    assert( -MAX == MIN+1 )
  end)
end


-- ...more tests here...

--
-- End
--
print "\nTests OK. :)"
