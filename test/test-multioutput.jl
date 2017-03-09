@verilog function multioutput(inputwire::Wire{3:0v})
  val1 = inputwire[1:0v]
  val2 = inputwire[msb:2v]
  return (val1, val2)
end
#
#@test multioutput(0b1100) == 0b0011
