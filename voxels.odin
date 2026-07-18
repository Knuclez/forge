package testsito

import "core:fmt"
import "core:math/linalg/glsl"

N_CHUNKS :: 4
CHUNK_WIDTH :: 16
CHUNK_HEIGHT :: 16
N_VOXELS :: N_CHUNKS * 256 

init_world::proc(engine : ^Engine){
    init_map_chunks(engine)
    init_voxels(engine)
}


init_map_chunks::proc(engine : ^Engine){
    chunk_columns_amt :i32= N_CHUNKS / 2
    chunk_x : i32
    chunk_z : i32
    for i:i32 = 0; i < N_CHUNKS; i += 1 {
	working_chunk : ^MapChunk = &engine.map_chunks[i]
	chunk_x = i / chunk_columns_amt
	chunk_z = i % chunk_columns_amt
	working_chunk.position.x = f32(chunk_x)
	working_chunk.position.z = f32(chunk_z)
    }
}


init_voxels::proc(engine : ^Engine){
    amt_voxels_per_chunk_to_create :i32= CHUNK_WIDTH * CHUNK_WIDTH
    current_chunk : ^MapChunk
    current_chunk_index : i32
    current_x : i32
    current_z : i32
    for i:i32 = 0; i < N_VOXELS/CHUNK_WIDTH - 1; i += 1 {
	for j:i32 = 0; j <CHUNK_WIDTH; j+=1{
	    //falta generar el id

	    index := j+1+(i*CHUNK_WIDTH)
	    fmt.println("index: ", index)
	    current_voxel : ^Voxel = &engine.voxels[index] //+1 por que quiero dejar el 0 como nul-space
	    current_voxel.position = glsl.mat4(1.0)
	    current_voxel.rotation = glsl.mat4(1.0)
	    current_voxel.scale = glsl.mat4(1.0)


	    current_chunk_index = index / amt_voxels_per_chunk_to_create 
	    if current_chunk_index > N_CHUNKS {
		fmt.println("Error creating voxels, current_chunk is bigger than N_CHUNK")
		return
	    }
	
	    fmt.println(current_chunk_index)
	    current_chunk = &engine.map_chunks[current_chunk_index]
	    current_x = j 
	    current_z = i % CHUNK_WIDTH

	    transl_x :f32= f32(current_x) + (CHUNK_WIDTH * current_chunk.position.x)
	    transl_z :f32= -f32(current_z) + (CHUNK_WIDTH * current_chunk.position.z)
	    //fmt.println("x local",current_x)
	    //fmt.println("x del chunk: ", current_chunk.position.x)
	    //fmt.println("translation total: ", transl_x)
	    translate_x_mat4(&current_voxel.position, transl_x)
	    translate_z_mat4(&current_voxel.position, transl_z)
	    scale_mat4(&current_voxel.scale, 1)
	    current_voxel.model = current_voxel.scale * current_voxel.position * current_voxel.rotation
	}
    }
}


voxels_tick_frame::proc(engine : ^Engine, current_time :f32){
    for &voxel in engine.voxels {
	//rotate_y_mat4(&voxel.rotation, current_time / 50)
	//voxel.model = voxel.scale * voxel.position * voxel.rotation
    }
}
