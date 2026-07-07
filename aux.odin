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

rotate_z_mat4::proc(to_rotate : ^glsl.mat4, rotation_value: f32) {
    sin_tita : f32 = glsl.sin(rotation_value)
    cos_tita : f32 = glsl.cos(rotation_value)
    rot_mat : glsl.mat4 = {cos_tita, sin_tita, 0, 0,
			    -sin_tita, cos_tita, 0, 0,
			    0, 0, 1, 0,
			    0, 0, 0, 1}
    to_rotate^ =  to_rotate^ * rot_mat
}

rotate_y_mat4::proc(to_rotate : ^glsl.mat4, rotation_value: f32){
    sin_tita : f32 = glsl.sin(rotation_value)
    cos_tita : f32 = glsl.cos(rotation_value)
    rot_mat : glsl.mat4 = {cos_tita, 0, sin_tita, 0,
			    0, 1, 0, 0,
			    -sin_tita, 0,cos_tita, 0,
			    0, 0, 0, 1}
    to_rotate^ =  to_rotate^ * rot_mat
}

rotate_x_mat4::proc(to_rotate : ^glsl.mat4, rotation_value: f32){
    sin_tita : f32 = glsl.sin(rotation_value)
    cos_tita : f32 = glsl.cos(rotation_value)
    rot_mat : glsl.mat4 = {1, 0, 0, 0,
			    0,cos_tita, -sin_tita, 0,
			    0,sin_tita, cos_tita, 0,
			    0, 0, 0, 1}
    to_rotate^ =  to_rotate^ * rot_mat
}

scale_mat4::proc(to_scale : ^glsl.mat4, scale_value: f32){
    scale_mat : glsl.mat4 = {scale_value, 0, 0, 0,
			     0, scale_value, 0, 0,
			     0, 0, scale_value, 0,
			     0, 0, 0, 1.0}
    to_scale^ = scale_mat * to_scale^ 
}

translate_z_mat4::proc(to_translate : ^glsl.mat4, translate_value: f32){
    trans_mat := glsl.mat4(1.0)
    trans_mat[3][2] = translate_value

    to_translate^ =  to_translate^ * trans_mat
}
translate_y_mat4::proc(to_translate : ^glsl.mat4, translate_value: f32){
     trans_mat := glsl.mat4(1.0)
    trans_mat[3][1] = translate_value

    to_translate^ = to_translate^ * trans_mat
}
translate_x_mat4::proc(to_translate : ^glsl.mat4, translate_value: f32){
    trans_mat := glsl.mat4(1.0)
    trans_mat[3][0] = translate_value

    to_translate^ = to_translate^ * trans_mat
}

implement_orthographic_projection::proc(left : f32,right : f32,
    top : f32,bottom : f32,near : f32,far : f32) -> glsl.mat4 {
    proj_mat := glsl.mat4(1.0)
    proj_mat[0][0] = 2.0 / (right - left)
    proj_mat[1][1] = 2.0 / (bottom - top)
    proj_mat[2][2] = -2.0 / (far - near)
    proj_mat[3][0] = -(right + left) / (right - left)
    proj_mat[3][1] = -(bottom + top) / (bottom - top)
    proj_mat[3][2] = -(far + near) / (far - near)
    return proj_mat
}
/*
fovy – Specifies the field of view angle in the y direction. Expressed in radians.
aspect – Specifies the aspect ratio that determines the field of view in the x direction. The aspect ratio is the ratio of x (width) to y (height).
near – Specifies the distance from the viewer to the near clipping plane (always positive).
far – Specifies the distance from the viewer to the far clipping plane (always positive).

T const tanHalfFovy = tan(fovy / static_cast<T>(2));

		mat<4, 4, T, defaultp> Result(static_cast<T>(0));
		Result[0][0] = static_cast<T>(1) / (aspect * tanHalfFovy);
		Result[1][1] = static_cast<T>(1) / (tanHalfFovy);
		Result[2][2] = - (zFar + zNear) / (zFar - zNear);
		Result[2][3] = - static_cast<T>(1);
		Result[3][2] = - (static_cast<T>(2) * zFar * zNear) / (zFar - zNear);
		return Result;
*/
implement_perspective_projection::proc(fov_y : f32, aspect : f32, near :f32, far :f32) -> glsl.mat4 {
    tan_half_fov_y : f32 = glsl.tan(fov_y/2)
    res := glsl.mat4(0.0)
    res[0][0] = 1/(tan_half_fov_y * aspect) 
    res[1][1] = -1/(tan_half_fov_y) 
    res[2][2] = far / (near-far)
    res[3][2] = (far * near) / (near-far)
    res[2][3] = -1
    return res
}
