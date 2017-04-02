# Verilog.jl

A Verilog-generation DSL for Julia.  Inspired by Chisel, but we like Julia
better.  Not having to type in semicolons alone makes it worth it!

Write your favorite verilog module as a julia function, by prefixing with
the `@verilog` macro.

```julia
@verilog function arbitrary_binary(v1::Wire, v2::Wire{4:0v}, bits)
  @suffix "$(bits)_bit"
  @input v1 (bits-1):0v
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

You can also write functions that call other functions.  Be sure to only call
functions directly as an assignment to a new wire.  Otherwise, the software emulation
will work fine, but the verilog will not correctly generate.

```julia
@verilog function yet_another_arbitrary_binary(v1::Wire, bits)
  @suffix "$(bits)_bit"
  @input v1 (bits-1):0v

  previous_function = arbitrary_binary(v1, v1[6:2v], bits)

  result = Wire(0b11100111, 8) & previous_function
end
```

call this new function with no wire parameters:

```julia
julia> yet_another_arbitrary_binary(8)
```

And shall be emitted the following verilog:

```verilog
module yet_another_arbitrary_binary_8_bit(
  input [7:0] v1,
  output [7:0] result);

  wire [7:0] previous_function;
  arbitrary_binary_8_bit arbitrary_binary_8_bit_previous_function(
    .v1 (v1),
    .v2 (v1[6:2]),
    .result (previous_function));
  assign result = ({8'b11100111} & previous_function);

endmodule
```

You can also have multiple outputs by returning a

## Goodies.

You can dereference wires using backward notation:

```julia
  w2[5:0v] = w1[1:6v]
```

transpiles to:

```verilog
  w2[5:0] = {w1[1], w1[2], w1[3], w1[4], w1[5], w1[6]};
```

You can use the ```msb``` keyword in both referencing and dereferencing to
automatically link to the most significant bit in a wire.

```julia
  w1 = Wire{5:0v}(0b10101)       #constant wire
  w2 = w1[msb]
  w3 = w1[msb:1v]
  w4 = w1[(msb-2):2v]

  w5 = Wire{4:0v}()              #undefined wire
  w5[msb] = w1[0]
  w5[(msb-1):3v] = w1[1:0v]
  w5[2:(msb-4)v] = w1[2:0v]
```

Ignoring the wire declarations, transpiles to:

```verilog
  w2 = w1[5];
  w3 = w1[5:1];
  w4 = w1[3:2];

  w5[5] = w1[0];
  w5[4:3] = w1[1:0];
  w5[2:0] = w1[2:0];
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

### On wire arrays

Do the natural thing and use the non-initializing `Array{Wire{<descriptor>}}(n)`
constructor from Julia.  Note that when transpiling to verilog, the wire arrays
will be down-shifted by one to make them one-indexed (this feature may change
in the future!).  Currently, binary muxes are not supported.

Gotchas:
* Assigning to wire array member partials is not allowed:
  ```
    my_array = Array{Wire{1:0v},1}(6)
    my_array[1]       = Wire(0b11,2)                    # <== this is OK.
    my_array[2][1:0v] = Wire(0b11,2)                    # <== don't do this.
  ```
* Assigning wire array member partials with a function is not allowed:
  ```
    my_array[3][1:0v] = some_verilog_module(some_input) # <== don't do this.
  ```

### Verilation

(linux-only) if you have a working version of "verilator", you can use the
verilate macro.
```
  @verilate my_favorite_function (parameter tuple)
```
This will create a function ```my_favorite_function_c```  which takes unsigned
integers and returns tuples of 64-bit unsigned integers.

### What's that `@suffix` macro?  
If you have parameter(s) that you'd like to use to trigger creation of multiple
instances of the module, use that.  If you have parameters that you're tuning,
and won't use multiple versions, don't bother.

### What's the `@input` macro?  
If you have a vaguely-typed wire parameter in your function, as in you'd like
the number of wires to be dependent on a non-wire passed value, you will want to
enforce that type dependence using this macro.  Bad things will happen otherwise.

### How does Verilog.jl know what to turn into the result?
Since Julia automatically outputs the last line of your function as the result,
the name of the last assigned identifier will be the name of the output.  If you
fail to return an value associated with an identifier, undefined behavior may
result.  In the future, this will throw an error.

## On combinational logic.

Remember, hardware uses combinational logic.  Obviously, Julia is sequential,
not combinational.  Make sure you're never attempting to update any of your wire
values.  If you do that, Verilog.jl will thread everything correctly.  To keep
things easy to visualize for yourself, aggressively assign new identifiers for
intermediate steps.  The `@verilog` macro will rewrite them and present them as
wires in the implementation of the module.

Coming Soon:
* better documentation!
* more unit tests!
* support for sequential logic
* arithmetic operations on wires longer than 64-bits
* translation of muxes and simple conditionals
* tools for automatic verification
* automatically convert println() to nonsynthesizable "display"
