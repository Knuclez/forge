package testsito

import "core:fmt"
import "core:math/linalg/glsl"

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

rotate_z_mat4::proc(to_rotate : glsl.mat4, rotation_value: f32) -> glsl.mat4{
    sin_tita : f32 = glsl.sin(rotation_value)
    cos_tita : f32 = glsl.cos(rotation_value)
    rot_mat : glsl.mat4 = {cos_tita, sin_tita, 0, 0,
			    -sin_tita, cos_tita, 0, 0,
			    0, 0, 1, 0,
			    0, 0, 0, 1}
    result :glsl.mat4 = rot_mat * to_rotate
    return result
}

rotate_y_mat4::proc(to_rotate : ^glsl.mat4, rotation_value: f32){
    sin_tita : f32 = glsl.sin(rotation_value)
    cos_tita : f32 = glsl.cos(rotation_value)
    rot_mat : glsl.mat4 = {cos_tita, 0, sin_tita, 0,
			    0, 1, 0, 0,
			    -sin_tita, 0,cos_tita, 0,
			    0, 0, 0, 1}
    to_rotate^ = rot_mat * to_rotate^
}

rotate_x_mat4::proc(to_rotate : ^glsl.mat4, rotation_value: f32){
    sin_tita : f32 = glsl.sin(rotation_value)
    cos_tita : f32 = glsl.cos(rotation_value)
    rot_mat : glsl.mat4 = {1, 0, 0, 0,
			    0,cos_tita, -sin_tita, 0,
			    0,sin_tita, cos_tita, 0,
			    0, 0, 0, 1}
    to_rotate^ = rot_mat * to_rotate^
}

scale_mat4::proc(to_scale : ^glsl.mat4, scale_value: f32){
    scale_mat : glsl.mat4 = {scale_value, 0, 0, 0,
			     0, scale_value, 0, 0,
			     0, 0, scale_value, 0,
			     0, 0, 0, 1.0}
    to_scale^ = scale_mat * to_scale^ 
}

translate_z_mat4::proc(to_translate : ^glsl.mat4, translate_value: f32){
    to_translate[3][2] = translate_value
}
translate_x_mat4::proc(to_translate : ^glsl.mat4, translate_value: f32){
    to_translate[3][0] = translate_value
}
