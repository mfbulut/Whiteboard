package main

import "core:fmt"
import "core:math/linalg"

import k2 "karl2d"

Vec2 :: [2]f64

BACKGROUND_COLOR :: k2.Color{22, 29, 50, 255}

main :: proc() {
    k2.init(1280, 720, "Whiteboard", {.Windowed_Resizable})
    k2.set_cursor_visible(false)
    
    load_whiteboard()

    for k2.update() {
        update_camera()
        update_brush()

        k2.clear(BACKGROUND_COLOR)
        
        draw_shapes()
        
        mouse_pos := k2.get_mouse_position()
        if k2.mouse_button_is_held(.Left) {
            k2.draw_circle(mouse_pos, f32(brush_thickness), k2.WHITE, int(brush_thickness))
        } else if k2.mouse_button_is_held(.Right) {
            k2.draw_circle_outline(mouse_pos, f32(brush_thickness), 1, k2.WHITE, int(brush_thickness))
        } else {
            k2.draw_circle_outline(mouse_pos, f32(brush_thickness), 1, brush_color, int(brush_thickness))
        }

        k2.present()
        free_all(context.temp_allocator)
    }

    save_whiteboard()
}