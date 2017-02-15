# Verilog.jl

A Verilog-generation DSL for Julia.  Inspired by Chisel, but we like Julia
better.

How to use:

Use the Wire{R} type.  This is a datatype that represents an indexed array of
3-value logic (1,0,X).  To make your stuff look more verilog-ey, the "v" suffix
for unit ranges is provided.

Eg:  
* Wire{6:0v} is roughly equivalent to `wire [6:0]`
* Wire{12:1v} is roughly equivalent to `wire [12:1]`
* SingleWire is aliased to Wire{0:0v}, roughly equivalent to `wire`

Prefix julia functions you'd like to turn into verilog modules with the `@verilog`
macro.

```
@verilog function arbitrary_binary(v1::Wire, v2::Wire{4:0v}, bits)
  @name_suffix "$(bits)_bit"
  @wire v1 (bits-1):0v
  result = v1 ^ Wire(Wire(0b0000,4), v2[4:1v])
end
```

Becomes:
```
module arbitrary_binary_8_bit(
  input [7:0] v1,
  input [4:0] v2,
  output [7:0] result);

  assign result = (v1 ^ {4'b0000,v2[4:1]});

endmodule
```
