package main

import "core:fmt"
import "core:os"

import k2 "karl2d"

BACKGROUND_COLOR :: k2.Color{22, 29, 50, 255}

main :: proc() {
    k2.init(1280, 720, "Whiteboard", { anti_alias = true, window_mode = .Windowed_Resizable})
    k2.set_cursor_visible(false)

    docs, _ := os.user_documents_dir(context.allocator)
    save_path, _ := os.join_path({docs, "whiteboard.bin"}, context.allocator)
    load_whiteboard(save_path)
    defer save_whiteboard(save_path)

    for k2.update() {
        update_camera()
        update_brush()

        k2.clear(BACKGROUND_COLOR)

        draw_shapes()

        mouse_pos := k2.get_mouse_position()
        screen_size := k2.get_screen_size()

        if k2.mouse_button_is_held(.Left) {
            k2.draw_circle(mouse_pos, f32(brush_thickness), brush_color, 64)
        } else if k2.mouse_button_is_held(.Right) {
            k2.draw_circle_outline(mouse_pos, f32(brush_thickness), 1, k2.WHITE, 64)
        } else {
            k2.draw_circle_outline(mouse_pos, f32(brush_thickness), 1, brush_color, 64)
        }

        k2.present()
    }
}