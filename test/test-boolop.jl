#let's make sure our boolean operations behave.

#NOT
@test_string "[01101011]" string(~Wire(0b10010100))

#AND
@test_string "[10000100]" Wire(0b10010100) & Wire(0b10100110)

#OR
@test_string "[10110110]" Wire(0b10010100) | Wire(0b10100110)
