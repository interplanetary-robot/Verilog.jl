#let's make sure our boolean operations behave.

#NOT
@test_string "Wire{7:0v}(0b01101011)" string(~Wire(0b10010100))

#AND
@test_string "Wire{7:0v}(0b10000100)" Wire(0b10010100) & Wire(0b10100110)

#OR
@test_string "Wire{7:0v}(0b10110110)" Wire(0b10010100) | Wire(0b10100110)
