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

  assign result = {wirearray[0], wirearray[1], wirearray[2], wirearray[3]};

endmodule
"""
