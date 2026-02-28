package main

import k2 "karl2d"

Camera :: struct {
    target: Vec2,
    zoom:   f64,
}

to_64 :: proc(v: k2.Vec2) -> Vec2 {
    return {f64(v.x), f64(v.y)}
}

screen_to_world :: proc(screen_pos: Vec2, cam: Camera) -> Vec2 {
    return screen_pos / cam.zoom + cam.target
}

world_to_screen :: proc(world_pos: Vec2, cam: Camera) -> k2.Vec2 {
    p := (world_pos - cam.target) * cam.zoom
    return k2.Vec2{f32(p.x), f32(p.y)}
}

update_camera :: proc() {
    mouse_pos := to_64(k2.get_mouse_position())
    if !k2.key_is_held(.Left_Control) {
        wheel := f64(k2.get_mouse_wheel_delta())
        
        if wheel != 0 {
            old_zoom := camera.zoom
            camera.zoom = clamp(old_zoom * (1.0 + wheel * 0.1), 1e-15, 1e-3)
            camera.target += mouse_pos * (1.0 / old_zoom - 1.0 / camera.zoom)
            if k2.key_is_held(.Left_Shift) {
                brush_radius *= camera.zoom / old_zoom
            }
        }
    }
    if k2.mouse_button_is_held(.Middle) || k2.key_is_held(.Space) {
        delta := to_64(k2.get_mouse_delta())
        if delta.x != 0 || delta.y != 0 {
            camera.target -= delta / camera.zoom
        }
    }
}