hex=function (i) return "0x"..string.format("%X", i) end
print(hex(0x54|0x55))
print(hex(0x54&0x66))
print(hex(0x54^^0x66))
print(hex(~0x54))
print(hex(0xF<< 4))
print(hex(0xF0>> 4))
a,b=0x54,0x55
print(hex(a),"|",hex(b), "=",hex(a|b))
print(hex(a),"|","0x55", "=",hex(a|0x55))
print(hex(a),"|","0x5|0x50 (", hex(0x5|0x50), ") =",hex(a|(0x5|0x50)))
a,b=0x54,0x66
print(hex(a),"&",hex(b), "=",hex(a&b))
print(hex(a),"&","0x66", "=",hex(a&0x66))
print(hex(a),"^^",hex(b), "=",hex(a^^b))
print(hex(a),"^^","0x66", "=",hex(a^^0x66))
print("~"..hex(a),"=",hex(~a))
a,b=0xF,0xF0
print(hex(a).."<<4","=",hex(a<<4))
print(hex(b)..">>4","=",hex(b>>4))
a,b=0xF,4
print(hex(a).."<<"..b,"=",hex(a<<b))
a,b=0xF0,4
print(hex(a)..">>"..b,"=",hex(a>>b))
