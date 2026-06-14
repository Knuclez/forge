package testsito

import "core:fmt"

slice_string_until_null::proc(to_slice : ^[256]u8) -> string{
    i := 0
    for letter in to_slice{
	if letter == 0{
	    break
	}
	i += 1
    }
    return string(to_slice[:i])
}
