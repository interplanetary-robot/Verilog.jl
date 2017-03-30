@verilog function wa(x::Wire{1:0v})

  wirearray = Vector{Wire{1:0v}}(4)

  for idx = 1:4
    wirearray[idx] = x
  end

  result = Wire([wirearray[idx] for idx in 1:4]...)

end

@test wa() == """
module wa(
  input [1:0] x,
  output [7:0] result);

  wire [1:0] wirearray[3:0];

  assign wirearray[0] = x;
  assign wirearray[1] = x;
  assign wirearray[2] = x;
  assign wirearray[3] = x;
  assign result = {wirearray[0],wirearray[1],wirearray[2],wirearray[3]};
endmodule
"""

@verilog function wa2(x::Wire{1:0v})

  wirearray = Vector{Wire{1:0v}}(4)

  wirearray[1] = Wire(0x3, 2)

  for idx = 2:4
    wirearray[idx] = x
  end

  result = Wire([wirearray[idx] for idx in 1:4]...)

end

@test wa2() == """
module wa2(
  input [1:0] x,
  output [7:0] result);

  wire [1:0] wirearray[3:0];

  assign wirearray[0] = 2'b11;
  assign wirearray[1] = x;
  assign wirearray[2] = x;
  assign wirearray[3] = x;
  assign result = {wirearray[0],wirearray[1],wirearray[2],wirearray[3]};
endmodule
"""

@verilog function flipme(x::Wire{1:0v})
  flipped = Wire(x[0], x[1])
end

@verilog function wa3(x::Wire{1:0v})

  wirearray = Vector{Wire{1:0v}}(4)

  wirearray[1] = x
  wirearray[2] = flipme(wirearray[1])

  for idx = 3:4
    wirearray[idx] = x
  end

  result = Wire([wirearray[idx] for idx in 1:4]...)

end

@test wa3() == """
module wa3(
  input [1:0] x,
  output [7:0] result);

  wire [1:0] wirearray[3:0];

  flipme flipme_wirearray_1(
    .x (wirearray[0]),
    .flipped (wirearray[1]));

  assign wirearray[0] = x;
  assign wirearray[2] = x;
  assign wirearray[3] = x;
  assign result = {wirearray[0],wirearray[1],wirearray[2],wirearray[3]};
endmodule
"""

@verilog function twooutputs(inp::Wire{1:0v})
  andor = Wire(inp[1] & inp[0], inp[1] | inp[0])
  xandor = andor ^ inp
  (andor, xandor)
end


@verilog function wa4(x::Wire{1:0v})

  wirearray = Vector{Wire{1:0v}}(4)

  wirearray[1] = x
  (wirearray[2], wirearray[3]) = twooutputs(wirearray[1])
  wirearray[4] = x

  result = Wire([wirearray[idx] for idx in 1:4]...)

end

@test wa4() == """
module wa4(
  input [1:0] x,
  output [7:0] result);

  wire [1:0] wirearray[3:0];

  twooutputs twooutputs_wirearray_1_wirearray_2(
    .inp (wirearray[0]),
    .andor (wirearray[1]),
    .xandor (wirearray[2]));

  assign wirearray[0] = x;
  assign wirearray[3] = x;
  assign result = {wirearray[0],wirearray[1],wirearray[2],wirearray[3]};
endmodule
"""
