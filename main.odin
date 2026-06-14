package testsito

import "core:fmt"
import "vendor:sdl2"

FPS :: 60
FRAME_TIME :: 1000/FPS

main::proc() {
    app : Application
    looping : bool = true

    init_aplication(&app) 

    last_frame_time : u32 = sdl2.GetTicks()
    for looping {
	fmt.println("empieza el loop")
	current_time : u32 = sdl2.GetTicks()
	elapsed_time : u32 = current_time - last_frame_time
	last_frame_time = current_time

	delta : f32 = f32(elapsed_time) / f32(1000)
	process_input(&looping)
	draw_frame(&app, delta)

	fmt.println("medio el loop")
	frame_time :u32 = sdl2.GetTicks() - current_time
	if frame_time < FRAME_TIME {
	    sdl2.Delay(FRAME_TIME - frame_time)
	}

	fmt.println("termina el loop")
    }

}

init_aplication::proc(app : ^Application){
    app.is_debug_mode = true
    init_sdl(app)
    init_vulkan(app)
    clean_up_vulkan(app)
}

process_input::proc(looping : ^bool){
    event : sdl2.Event
    if sdl2.PollEvent(&event){
	#partial switch event.type {
	    case sdl2.EventType.QUIT:
		looping^ = false
	}
    }
}
