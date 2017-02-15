my_wire = Wire(4)

#test basic properties of this wire.
@test length(my_wire) == 4
@test range(my_wire) == 3:0v
@test !Verilog.assigned(my_wire)

@test_string "Wire{3:0v}(0bXXXX)" my_wire

#test that attempting to access the wire at position 0 causes an error.
@test_throws Verilog.UnassignedError my_wire[0]

#set the first value of my_wire to 0
my_wire[0] = Wire(false)

@test_string "Wire{3:0v}(0bXXX0)" my_wire

#test that attempting to set the value of the wire once it's set causes an error.
@test_throws Verilog.AssignedError my_wire[0] = Wire(true)

#show that attempting to access multiple indices throws an error when they're unset.
@test_throws Verilog.UnassignedError my_wire[0:2]

@test_string "Wire{7:0v}(0b10010010)" Wire(0b10010010)

my_short_wire = Wire(0b110, 3)
#note that an array of bools is input in reverse from an bitarry.
@test_string "Wire{2:0v}(0b110)" my_short_wire

#show that attempting to set a partially set value throws an error.
@test_throws Verilog.AssignedError my_wire[0:2] = my_short_wire

#as does trying to set different sizes.
@test_throws Verilog.SizeMismatchError my_wire[0:3] = my_short_wire

#but working with fully set values is ok.
my_wire[1:3] = my_short_wire
@test_string "Wire{3:0v}(0b1100)" my_wire

###############################################################################
#test unsigned integer based constructors.
