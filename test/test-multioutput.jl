@verilog function multioutput(inputwire::Wire{3:0v})
  val1 = inputwire[1:0v]
  val2 = inputwire[msb:2v]
  return (val1, val2)
end

@test multioutput(0b1100) == 0b0011

#next, write two functions.
@verilog function vf(x::Wire{3:0v})
  o1 = x[1:0v]
  o2 = x[msb:2v]
  (o1, o2)
end

@test vf() == """
module vf(
  input [3:0] x,
  output [1:0] o1,
  output [1:0] o2);

  assign o1 = x[1:0];
  assign o2 = x[3:2];
endmodule
"""

@verilog function calls_vf(z::Wire{3:0v})
  c1, c2 = vf(z)
  res = c1 & c2
end

@test calls_vf() == """
module calls_vf(
  input [3:0] z,
  output [1:0] res);

  wire [1:0] c1;
  wire [1:0] c2;

  vf vf_c1_c2(
    .x (z),
    .o1 (c1),
    .o2 (c2));

  assign res = (c1 & c2);
endmodule
"""

@verilog function calls_vf_2(z::Wire{3:0v})
  c2 = Wire(3:0v)
  c1, c2[1:0v] = vf(z)
  res = c1 & c2
end

@test calls_vf_2() == """
module calls_vf_2(
  input [3:0] z,
  output [1:0] res);

  wire [1:0] c1;
  wire [3:0] c2;

  vf vf_c1_c2_1_0(
    .x (z),
    .o1 (c1),
    .o2 (c2[1:0]));

  assign res = (c1 & c2);
endmodule
"""
