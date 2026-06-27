package testsito

import "core:fmt"
import "core:math/linalg/glsl"

init_voxels::proc(engine : ^Engine){
    i : u32 = 0
    for &voxel in engine.voxels {
	voxel.position = glsl.mat4(1.0)
	voxel.rotation = glsl.mat4(1.0)
	voxel.scale = glsl.mat4(1.0)

	voxel.position[3][0] = f32(i) * f32(0.5)

	//voxel.model = voxel.scale * voxel.rotation * voxel.position
	voxel.model = voxel.position
	i += 1
    }
}
