package testsito

import "core:fmt"
import "core:math/linalg/glsl"
import "vendor:sdl2"
import vk "vendor:vulkan"

FPS :: 100
FRAME_TIME :: 1000/FPS

main::proc() {
    engine : Engine 
    looping : bool = true

    init_engine(&engine) 

    last_frame_time : u32 = sdl2.GetTicks()
    current_time : u32
    elapsed_time : u32
    for looping {
	current_time = sdl2.GetTicks()
	elapsed_time = current_time - last_frame_time
	//fmt.println("elapsed_time: "elapsed_time)

	last_frame_time = current_time

	delta : f32 = f32(elapsed_time) / f32(1000)
	process_input(&looping)
	if !looping { break }
	draw_frame(&engine, &engine.vulkan_app, f32(current_time))

	frame_time :u32 = sdl2.GetTicks() - current_time
	if frame_time < FRAME_TIME {
	    sdl2.Delay(FRAME_TIME - frame_time)
	}

    }
    
    vk.DeviceWaitIdle(engine.vulkan_app.device)
    terminate_engine(&engine)
}

init_engine::proc(engine : ^Engine){
    engine.vulkan_app.is_debug_mode = true
    init_voxels(engine)
    init_sdl(&engine.vulkan_app)
    init_vulkan(engine, &engine.vulkan_app)
}

terminate_engine::proc(engine : ^Engine){
    clean_up_vulkan(&engine.vulkan_app)
}

process_input::proc(looping : ^bool){
    event : sdl2.Event
    for sdl2.PollEvent(&event){
	#partial switch event.type {
	    case sdl2.EventType.QUIT:
		looping^ = false
	    case sdl2.EventType.KEYDOWN:
		looping^ = false
	}
    }
}


init_voxels::proc(engine : ^Engine){
    i : u32 = 0
    for &voxel in engine.voxels {
	model_matrix : glsl.mat4 = glsl.mat4(1.0)
	voxel.position = glsl.mat4(1.0)
	voxel.rotation = glsl.mat4(1.0)
	voxel.scale = glsl.mat4(1.0)

	model_matrix[3][0] = f32(i) * f32(1)

	rotate_y_mat4(&model_matrix, 500)
	rotate_x_mat4(&model_matrix, -50)
	scale_mat4(&model_matrix, 0.2)
	voxel.model = model_matrix
	i += 1
    }
}
