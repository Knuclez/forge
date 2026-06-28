package testsito

import "core:fmt"
import "core:math/linalg/glsl"

init_voxels::proc(engine : ^Engine){
    i : u32 = 0
    for &voxel in engine.voxels {
	model_matrix : glsl.mat4 = glsl.mat4(1.0)
	voxel.position = glsl.mat4(1.0)
	voxel.rotation = glsl.mat4(1.0)
	voxel.scale = glsl.mat4(1.0)

	model_matrix[3][0] = f32(i) * f32(1)
	//voxel.position[3][1] = f32(i) * f32(0.1)
	//voxel.position[3][2] = f32(i) * f32(0.1)

	rotate_y_mat4(&model_matrix, 500)
	rotate_x_mat4(&model_matrix, -50)
	scale_mat4(&model_matrix, 0.5)
	voxel.model = model_matrix
	i += 1
    }
}
