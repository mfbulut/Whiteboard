package main

import "core:os"
import k2 "karl2d"

BACKGROUND_COLOR :: k2.Color{22, 29, 50, 255}

main :: proc() {
    k2.init(1280, 720, "Whiteboard", { anti_alias = true, window_mode = .Windowed_Resizable})
    k2.set_cursor_hidden(false)

    docs := os.user_documents_dir(context.allocator) or_else panic("Document Folder Not Found")
    save_path := os.join_path({docs, "whiteboard.bin"}, context.allocator) or_else panic("Out Of Memory")
    load(save_path, &camera, &brush_thickness, &brush_color, &shapes)
    defer save(save_path, camera, brush_thickness, brush_color, shapes)

    for k2.update() {
        update_camera()
        update_brush()

        k2.clear({22, 29, 50, 255})

        draw_shapes()

        mouse_pos := k2.get_mouse_position()

        if k2.mouse_button_is_held(.Left) {
            k2.draw_circle(mouse_pos, brush_thickness, brush_color, 64)
        } else {
            k2.draw_circle_outline(mouse_pos, brush_thickness, 1, brush_color, 64)
        }

        k2.present()
    }
}