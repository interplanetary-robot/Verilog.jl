# Verilog.jl

A Verilog-generation DSL for Julia.  Inspired by Chisel, but we like Julia
better.

Write your favorite verilog module as a julia function, by prefixing with
the `@verilog` macro.

```julia
@verilog function arbitrary_binary(v1::Wire, v2::Wire{4:0v}, bits)
  @name_suffix "$(bits)_bit"
  @wire v1 (bits-1):0v
  result = v1 ^ Wire(Wire(0b0000,4), v2[4:1v])
end
```

You can execute this as a standard Julia function, passing Wire values:

```julia
julia> arbitrary_binary(Wire(0b10001011,8), Wire{4:0v}(0b11110), 8)
Wire{7:0v}(0b10000100)
```

Or you can pass it unsigned integers.
```julia
julia> arbitrary_binary(0b10001011, 0b11110, 8)
0x0000000000000084
```

Or if you strip the Wire parameters, and call it:

```julia
julia> arbitrary_binary(8)
```

outputs the string:

```verilog
module arbitrary_binary_8_bit(
  input [7:0] v1,
  input [4:0] v2,
  output [7:0] result);

  assign result = (v1 ^ {4'b0000,v2[4:1]});

endmodule
```

## A few notes.

### On the Wire type.  
This is a datatype that represents an indexed array of 3-value logic (1,0,X).  
To make your stuff look more verilog-ey, the "v" suffix
for unit ranges is provided.

Eg:  
* `Wire{6:0v}` is roughly equivalent to `wire [6:0]`
* `Wire{12:1v}` is roughly equivalent to `wire [12:1]`
* SingleWire is aliased to `Wire{0:0v}`, roughly equivalent to `wire`

### What's that `@name_suffix` macro?  
If you have parameter(s) that you'd like to use to trigger creation of multiple
instances of the module, use that.  If you have parameters that you're tuning,
and won't use multiple versions, don't bother.

### What's the `@wire` macro?  
If you have a vaguely-typed wire parameter in your function, as in you'd like
the number of wires to be dependent on a passed value, you can enforce that type
dependence using this macro.

### How does Verilog.jl know what to turn into the result?
Since Julia automatically outputs the last line of your function as the result,
the name of the last assigned identifier will be the name of the output.

## On combinational logic.

Remember, hardware uses combinational logic.  Obviously, Julia is sequential,
not combinational.  Make sure you're never attempting to update any of your wire
values.  If you do that, Verilog.jl will thread everything correctly.  To keep
things easy to visualize for yourself, aggressively assign new identifiers for
intermediate steps.  The `@verilog` macro will rewrite them and present them as

Coming Soon:
* support for sequential logic as well as combinatorial logic
* compiling verilog files into c library using Verilator
* tools for automatic verification
