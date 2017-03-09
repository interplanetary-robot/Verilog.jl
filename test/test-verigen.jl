
function g()
  Verilog.@verimode :verilog
  Verilog.@verigen g
  Verilog.@input my_wire 7:0v
  Verilog.@assign new_wire my_wire
  Verilog.@verifin
end

@test g() == """
module g(
  input [7:0] my_wire,
  output [7:0] new_wire);

  assign new_wire = my_wire;
endmodule
"""

function h()
  Verilog.@verimode :verilog
  Verilog.@verigen h
  Verilog.@input my_wire 7:0v
  Verilog.@assign new_wire ~(my_wire)
  Verilog.@verifin
end

@test h() == """
module h(
  input [7:0] my_wire,
  output [7:0] new_wire);

  assign new_wire = ~(my_wire);
endmodule
"""

@verilog function arbitrary_binary(v1::Wire, v2::Wire{4:0v}, bits)
  @suffix "$(bits)_bit"
  @input v1 (bits-1):0v
  result = v1 ^ Wire(Wire(0b0000,4), v2[4:1v])
end

@test_string "Wire{7:0v}(0b01011110)" arbitrary_binary(Wire{7:0v}(0b0101_0001), Wire{4:0v}(0b11110), 8)

@test arbitrary_binary(0b0101_0001, 0b11110, 8) == 0x000000000000005e

@test arbitrary_binary(8) == """
module arbitrary_binary_8_bit(
  input [7:0] v1,
  input [4:0] v2,
  output [7:0] result);

  assign result = (v1 ^ {4'b0000,v2[4:1]});
endmodule
"""

@verilog function set_inf_zero_bits(
  signbit::SingleWire,
  allzeros::SingleWire)

  result = Wire(allzeros & signbit, allzeros & (~signbit))
end

@test set_inf_zero_bits() == """
module set_inf_zero_bits(
  input signbit,
  input allzeros,
  output [1:0] result);

  assign result = {(allzeros & signbit),(allzeros & ~(signbit))};
endmodule
"""
