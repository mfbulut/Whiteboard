package main

import k2 "karl2d"

Camera :: struct {
    zoom: f64,
    position: Vec2,
}

camera := Camera{ zoom = 1e-8 }
target_zoom := 1e-8
drag_start: Vec2

update_camera :: proc() {
    mouse_pos := Vec2(k2.get_mouse_position())

    if !k2.key_is_held(.Left_Control) && !k2.key_is_held(.Left_Shift) && !k2.key_is_held(.G) {
        wheel := f64(k2.get_mouse_wheel_delta())
        if wheel != 0 {
            zoom_factor := 1.0 + wheel * 0.15
            target_zoom = clamp(target_zoom * zoom_factor, 1e-15, 1e-3)
        }
    }

    ZOOM_SMOOTH :: 0.15
    old_zoom := camera.zoom
    camera.zoom += (target_zoom - camera.zoom) * ZOOM_SMOOTH
    camera.position += mouse_pos * (1.0 / old_zoom - 1.0 / camera.zoom)

    PAN_SMOOTH :: 0.5

    if k2.mouse_button_went_down(.Middle) || k2.key_went_down(.Space) {
        drag_start = screen_to_world(mouse_pos)
    }

    if k2.mouse_button_is_held(.Middle) || k2.key_is_held(.Space) {
        target_position := drag_start - mouse_pos / camera.zoom
        camera.position += (target_position - camera.position) * PAN_SMOOTH
    }
}

screen_to_world_f64 :: proc(screen_pos: Vec2) -> Vec2 {
    return screen_pos / camera.zoom + camera.position
}

screen_to_world_f32 :: proc(screen_pos: k2.Vec2) -> Vec2 {
    return Vec2(screen_pos) / camera.zoom + camera.position
}

screen_to_world :: proc{screen_to_world_f32, screen_to_world_f64}

world_to_screen :: proc(world_pos: Vec2) -> k2.Vec2 {
    return k2.Vec2((world_pos - camera.position) * camera.zoom)
}