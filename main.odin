package testsito

import "core:fmt"
import "vendor:sdl2"
import vk "vendor:vulkan"

FPS :: 60
FRAME_TIME :: 1000/FPS

main::proc() {
    app : Application
    looping : bool = true

    init_aplication(&app) 

    last_frame_time : u32 = sdl2.GetTicks()
    for looping {
	current_time : u32 = sdl2.GetTicks()
	elapsed_time : u32 = current_time - last_frame_time
	last_frame_time = current_time

	delta : f32 = f32(elapsed_time) / f32(1000)
	process_input(&looping)
	if !looping { break }
	draw_frame(&app, f32(current_time))

	frame_time :u32 = sdl2.GetTicks() - current_time
	if frame_time < FRAME_TIME {
	    sdl2.Delay(FRAME_TIME - frame_time)
	}

    }
    
    vk.DeviceWaitIdle(app.device)
    clean_up_vulkan(&app)
}

init_aplication::proc(app : ^Application){
    app.is_debug_mode = true
    init_sdl(app)
    init_vulkan(app)
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
