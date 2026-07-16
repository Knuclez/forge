package testsito

import "core:fmt"
import "core:math/linalg/glsl"

N_ENGINE_VOXELS :: 1024

init_voxels::proc(engine : ^Engine){
    i : u32 = 0
    j : u32 = 0
    n_columns : u32 = 32
    column_len : u32 = N_ENGINE_VOXELS / n_columns
    for i < n_columns {
	for j < column_len {
	    current_voxel : ^Voxel = &engine.voxels[(i * column_len) + j]
	    current_voxel.position = glsl.mat4(1.0)
	    current_voxel.rotation = glsl.mat4(1.0)
	    current_voxel.scale = glsl.mat4(1.0)

	    translate_x_mat4(&current_voxel.position, f32(i))
	    translate_z_mat4(&current_voxel.position, -f32(j))
	    scale_mat4(&current_voxel.scale, 0.2)
	    current_voxel.model = current_voxel.scale * current_voxel.position * current_voxel.rotation
	    j += 1
	}
	j = 0
	i += 1	
    }
}


voxels_tick_frame::proc(engine : ^Engine, current_time :f32){
    for &voxel in engine.voxels {
	//rotate_y_mat4(&voxel.rotation, current_time / 50)
	//voxel.model = voxel.scale * voxel.position * voxel.rotation
    }
}
