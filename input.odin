package testsito

import "core:fmt"
import "vendor:sdl2"

is_mouse3_down : bool = false

process_input::proc(looping : ^bool){
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
	}
    }
}

interpret_key_down::proc(key_down_event : sdl2.Event){
    engine_p : ^Engine = get_engine_p()
    #partial switch key_down_event.key.keysym.sym{
	case sdl2.Keycode.ESCAPE:
	    engine_p.looping = false
	case sdl2.Keycode.w:
	    move_view_up(engine_p)
	case sdl2.Keycode.s:
	    move_view_down(engine_p)
	case sdl2.Keycode.a:
	    move_view_left(engine_p)
	case sdl2.Keycode.d:
	    move_view_right(engine_p)
    }
}

interpret_key_up::proc(key_up_event : sdl2.Event){
}

interpret_mouse_button_down::proc(mouse_button_down_event : sdl2.Event){
    switch mouse_button_down_event.button.button{
    case sdl2.BUTTON_MIDDLE:
	is_mouse3_down = true
	fmt.println("mouse3_down = ture")
    }
}

interpret_mouse_button_up::proc(mouse_button_up_event : sdl2.Event){
    switch mouse_button_up_event.button.button{
    case sdl2.BUTTON_MIDDLE:
	is_mouse3_down = false 
	fmt.println("mouse3_down false")
    }
}
//ENGINE EVENTS
move_view_up::proc(engine : ^Engine){
    translate_y_mat4(&engine.view_transform, 0.5)
}

move_view_down::proc(engine : ^Engine){
    translate_y_mat4(&engine.view_transform, -0.5)
}

move_view_right::proc(engine : ^Engine){
    translate_x_mat4(&engine.view_transform, -0.5)
}

move_view_left::proc(engine : ^Engine){
    translate_x_mat4(&engine.view_transform, 0.5)
}
