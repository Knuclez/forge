package testsito

import "core:fmt"
import "core:math/linalg/glsl"
import "vendor:sdl2"

is_mouse3_down : bool = false

process_sdl_events::proc(looping : ^bool, delta : f32){
    event : sdl2.Event
    for sdl2.PollEvent(&event){
	#partial switch event.type {
	    case sdl2.EventType.QUIT:
		looping^ = false
	    case sdl2.EventType.KEYDOWN:
		interpret_key_down(event)
	    case sdl2.EventType.KEYUP:
		interpret_key_up(event)
	    case sdl2.EventType.MOUSEBUTTONDOWN:
		interpret_mouse_button_down(event)
	    case sdl2.EventType.MOUSEBUTTONUP:
		interpret_mouse_button_up(event)
	    case sdl2.EventType.MOUSEMOTION:
		interpret_mouse_motion(event, delta)
	    case sdl2.EventType.MOUSEWHEEL:
		interpret_mouse_wheel(event, delta)
	    case sdl2.EventType.WINDOWEVENT:
		interpret_window_event(event)
	}
    }
}

interpret_key_down::proc(key_down_event : sdl2.Event){
    engine_p : ^Engine = get_engine_p()
    #partial switch key_down_event.key.keysym.sym{
	case sdl2.Keycode.ESCAPE:
	    engine_p.looping = false
	case sdl2.Keycode.w:
	    move_view_forwards(engine_p)
	case sdl2.Keycode.s:
	    move_view_backwards(engine_p)
	case sdl2.Keycode.a:
	    move_view_left(engine_p)
	case sdl2.Keycode.d:
	    move_view_right(engine_p)
    }
}

interpret_key_up::proc(key_up_event : sdl2.Event){
}

interpret_mouse_button_down::proc(event : sdl2.Event){
    mouse_button_down_event := event.button
    switch mouse_button_down_event.button{
    case sdl2.BUTTON_LEFT:
	cast_selection_ray(i32(mouse_button_down_event.x), i32(mouse_button_down_event.y))
    case sdl2.BUTTON_MIDDLE:
	is_mouse3_down = true
    }
}

interpret_mouse_button_up::proc(mouse_button_up_event : sdl2.Event){
    switch mouse_button_up_event.button.button{
    case sdl2.BUTTON_MIDDLE:
	is_mouse3_down = false 
    }
}

interpret_mouse_motion::proc(mouse_motion_event : sdl2.Event, delta : f32){
    engine_p : ^Engine = get_engine_p()
    if is_mouse3_down{
	rotate_view_transform(engine_p, mouse_motion_event.motion, delta)
    }
}

interpret_mouse_wheel::proc(mouse_wheel_event : sdl2.Event, delta : f32){
    engine_p : ^Engine = get_engine_p()
    scroll_amt := f32(mouse_wheel_event.wheel.y)
    move_view_z(engine_p, scroll_amt, delta)
}

interpret_window_event::proc(sdl_event : sdl2.Event){
    if sdl_event.window.event == sdl2.WindowEventID.SIZE_CHANGED{
	engine : ^Engine = get_engine_p()
	engine.vulkan_app.frame_buffer_resized = true
	fmt.println("sioze changed")
    }
}
//ENGINE EVENTS
move_view_up::proc(engine : ^Engine){
    translate_y_mat4(&engine.view_transform.position, -0.5)
}

move_view_down::proc(engine : ^Engine){
    translate_y_mat4(&engine.view_transform.position, 0.5)
}

move_view_forwards::proc(engine : ^Engine){
    translate_z_mat4(&engine.view_transform.position, -0.5)
}

move_view_backwards::proc(engine : ^Engine){
    translate_z_mat4(&engine.view_transform.position, 0.5)
}

move_view_right::proc(engine : ^Engine){
    translate_x_mat4(&engine.view_transform.position, -0.5)
}

move_view_left::proc(engine : ^Engine){
    translate_x_mat4(&engine.view_transform.position, 0.5)
}

move_view_z::proc(engine : ^Engine, scroll_amt:f32, delta:f32){
    //20 es speed arbtraira
    z_amt := scroll_amt * delta * 20
    translate_z_mat4(&engine.view_transform.position, z_amt)
}

rotate_view_transform::proc(engine : ^Engine, motion_event : sdl2.MouseMotionEvent, delta : f32){

    y_factor : f32 = f32(motion_event.xrel) * delta * 5
    //x_factor : f32 = f32(motion_event.yrel) * delta * 5
    rotate_y_mat4(&engine.view_transform.rotation, y_factor)
    //rotate_x_mat4(&engine.view_transform.rotation, x_factor)

}


cast_selection_ray::proc(screen_x : i32, screen_y :i32){
    fmt.println("click x: ", screen_x)
    fmt.println("click y: ", screen_y)
    ray_vector : glsl.vec4 = {f32(screen_x), f32(screen_y), 1, 0}

}
