package testsito

import "core:fmt"
import "core:math/linalg/glsl"
import "vendor:sdl2"
import vk "vendor:vulkan"

FPS :: 100
FRAME_TIME :: 1000/FPS

engine : Engine 

main::proc() {
    engine.looping = true

    init_engine(&engine) 
    
    last_frame_time : u32 = sdl2.GetTicks()
    current_time : u32
    elapsed_time : u32
    for engine.looping {
	current_time = sdl2.GetTicks()
	elapsed_time = current_time - last_frame_time
	//fmt.println("elapsed_time: "elapsed_time)

	last_frame_time = current_time

	delta : f32 = f32(elapsed_time) / f32(1000)
	process_input(&engine.looping)
	if !engine.looping { break }
	rotate_voxels(&engine, f32(current_time))
	draw_frame(&engine, &engine.vulkan_app, f32(current_time))

	frame_time :u32 = sdl2.GetTicks() - current_time
	if frame_time < FRAME_TIME {
	    sdl2.Delay(FRAME_TIME - frame_time)
	}

    }
    
    vk.DeviceWaitIdle(engine.vulkan_app.device)
    terminate_engine(&engine)
}

get_engine_p::proc() -> ^Engine{
    if engine == {} {
	fmt.println("Engine is nil")
    }
    return &engine
}

terminate_engine::proc(engine : ^Engine){
    clean_up_vulkan(&engine.vulkan_app)
}


init_engine::proc(engine : ^Engine){
    engine.vulkan_app.is_debug_mode = true
    init_voxels(engine)
    init_view_and_projection_transforms(engine)
    init_sdl(&engine.vulkan_app)
    init_vulkan(engine, &engine.vulkan_app)
}


init_sdl::proc(app : ^vkApplication){
    res := sdl2.CreateWindow("Titel", 30, 30, WINDOW_WIDTH, WINDOW_HEIGHT, {sdl2.WindowFlag.VULKAN})
    if res == nil{
	fmt.println("Fallo al crear la ventana en init_sdl")
	return
    }
    app.window = res 
}


init_voxels::proc(engine : ^Engine){
    i : u32 = 0
    for &voxel in engine.voxels {
	model_matrix : glsl.mat4 = glsl.mat4(1.0)
	voxel.position = glsl.mat4(1.0)
	voxel.rotation = glsl.mat4(1.0)
	voxel.scale = glsl.mat4(1.0)

	rotate_y_mat4(&model_matrix, 500)
	translate_x_mat4(&model_matrix, f32(i))
	scale_mat4(&model_matrix, 0.2)
	voxel.model = model_matrix
	i += 1
    }
}


rotate_voxels::proc(engine : ^Engine, current_time : f32){
    for &voxel in engine.voxels{
	//rotate_y_mat4(&voxel.model, current_time/50)
    }
}


init_view_and_projection_transforms::proc(engine : ^Engine){
    engine.view_transform = glsl.mat4(1.0)
    rotate_x_mat4(&engine.view_transform, -0.2) //Rotar negativo es hacia abajo
    translate_z_mat4(&engine.view_transform, -3)

    aspect_ratio : f32 = (f32(WINDOW_WIDTH)/2) / (f32(WINDOW_HEIGHT)/2)
    engine.projection_transform = implement_perspective_projection(f32(0.80), aspect_ratio, f32(0.1), f32(1000))
} 


