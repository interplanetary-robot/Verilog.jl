#sequential data constructs.

#tests the creation of an 8-bit register value.

@sequential function ld_reg8(din::Wire{7:0v}, clock::SingleWire, reset::SingleWire, ld::SingleWire)
  #an 8-bit register value.
  reg = Register{7:0v}()
  q_nxt = ((8 * ld) & din) | ((8 * (~ld)) & reg)

  @always posedge(clock) begin
    reg = (8 * ~reset) & q_nxt
  end
end

din_zer = Wire(0x00, 8)
din_one = Wire(0xFF, 8)
clocklo = Wire(false)
clockhi = Wire(true)
reset   = Wire(false)
nold    = Wire(false)
dold    = Wire(true)

l8 = __enc_ld_reg8()

res = l8(din_zer, clocklo, reset, nold)
println(res)
res = l8(din_zer, clockhi, reset, nold)
println(res)
res = l8(din_zer, clocklo, reset, dold)
println(res)
res = l8(din_zer, clockhi, reset, dold)
println(res)
res = l8(din_one, clocklo, reset, dold)
println(res)
res = l8(din_one, clockhi, reset, dold)
println(res)
res = l8(din_zer, clockhi, reset, dold)
println(res)
