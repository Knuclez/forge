package testsito

import "core:fmt"
import "vendor:sdl2"
import vk "vendor:vulkan"

FPS :: 60
FRAME_TIME :: 1000/FPS

main::proc() {
    engine : Engine 
    looping : bool = true

    init_engine(&engine) 

    last_frame_time : u32 = sdl2.GetTicks()
    for looping {
	current_time : u32 = sdl2.GetTicks()
	elapsed_time : u32 = current_time - last_frame_time
	last_frame_time = current_time

	delta : f32 = f32(elapsed_time) / f32(1000)
	process_input(&looping)
	if !looping { break }
	draw_frame(&engine.vulkan_app, f32(current_time))

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
    init_vulkan(&engine.vulkan_app)
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
