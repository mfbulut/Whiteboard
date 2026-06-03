package main

import k2 "karl2d"

camera := k2.Camera{ zoom = 1 }
target_zoom := f32(1)
drag_start: k2.Vec2

update_camera :: proc() {
    mouse_pos := k2.get_mouse_position()

    if !k2.key_is_held(.Left_Control) && !k2.key_is_held(.Left_Shift) && !k2.key_is_held(.G) {
        wheel := k2.get_mouse_wheel_delta()

        if wheel != 0 {
            zoom_factor := 1.0 + wheel * 0.15
            target_zoom = target_zoom * zoom_factor
        }
    }

    ZOOM_SMOOTH :: 0.15
    old_zoom := camera.zoom
    camera.zoom += (target_zoom - camera.zoom) * ZOOM_SMOOTH
    camera.target += mouse_pos * (1.0 / old_zoom - 1.0 / camera.zoom)

    PAN_SMOOTH :: 0.5

    if k2.mouse_button_went_down(.Middle) || k2.key_went_down(.Space) {
        drag_start = k2.screen_to_world(mouse_pos, camera)
    }

    if k2.mouse_button_is_held(.Middle) || k2.key_is_held(.Space) {
        target_position := drag_start - mouse_pos / camera.zoom
        camera.target += (target_position - camera.target) * PAN_SMOOTH
    }
}