package main

import k2 "karl2d"
import "core:math/linalg"

Camera :: struct {
    zoom: f64,
    position: Vec2,
}

camera := Camera{ zoom = 1e-6 }
target_zoom := 1e-6
drag_start: Vec2

update_camera :: proc() {
    mouse_pos := to_64(k2.get_mouse_position())

    if !k2.key_is_held(.Left_Control) {
        wheel := f64(k2.get_mouse_wheel_delta())
        if wheel != 0 {
            zoom_factor := 1.0 + wheel * 0.15
            target_zoom = clamp(target_zoom * zoom_factor, 1e-15, 1e-3)
        }
    }
    
    ZOOM_SMOOTH :: 0.15
    mouse_world_before := screen_to_world(mouse_pos, camera)
    camera.zoom += (target_zoom - camera.zoom) * ZOOM_SMOOTH
    mouse_world_after := screen_to_world(mouse_pos, camera)
    camera.position += mouse_world_before - mouse_world_after

    PAN_SMOOTH :: 0.5
    
    if k2.mouse_button_went_down(.Middle) || k2.key_went_down(.Space) {
        drag_start = screen_to_world(mouse_pos, camera)
    }
    
    if k2.mouse_button_is_held(.Middle) || k2.key_is_held(.Space) {
        target_position := drag_start - mouse_pos / camera.zoom
        camera.position += (target_position - camera.position) * PAN_SMOOTH
    }
}

to_64 :: proc(v: k2.Vec2) -> Vec2 {
    return {f64(v.x), f64(v.y)}
}

screen_to_world :: proc(screen_pos: Vec2, cam: Camera) -> Vec2 {
    return screen_pos / cam.zoom + cam.position
}

world_to_screen :: proc(world_pos: Vec2, cam: Camera) -> k2.Vec2 {
    p := (world_pos - cam.position) * cam.zoom
    return k2.Vec2{f32(p.x), f32(p.y)}
}