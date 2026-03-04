package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:math/linalg"

import "core:image"
import "core:image/jpeg"
import "core:image/bmp"
import "core:image/png"
import "core:image/tga"

import k2 "karl2d"

Vec2 :: [2]f64

BACKGROUND_COLOR :: k2.Color{22, 29, 50, 255}

main :: proc() {
    k2.init(1280, 720, "Whiteboard", {.Windowed_Resizable})
    k2.windows_set_file_drop_callback(process_file)
    k2.set_cursor_visible(false)

    docs, _ := os.user_documents_dir(context.allocator)
    file_path, _ := filepath.join({docs, "whiteboard.bin"}, context.allocator)
    load_whiteboard(file_path)

    for k2.update() {
        update_camera()
        update_brush()

        k2.clear(BACKGROUND_COLOR)

        draw_shapes()

        mouse_pos := k2.get_mouse_position()

        if mouse_pos.x <= 0 || mouse_pos.x > f32(k2.get_screen_width()) ||
           mouse_pos.y <= 0   || mouse_pos.y > f32(k2.get_screen_height()) {
            k2.set_cursor_visible(true)
        } else {
            k2.set_cursor_visible(false)
        }

        if k2.mouse_button_is_held(.Left) {
            k2.draw_circle(mouse_pos, max(f32(brush_thickness), 1), brush_color, 64)
        } else if k2.mouse_button_is_held(.Right) {
            k2.draw_circle_outline(mouse_pos, max(f32(brush_thickness), 1), 1, k2.WHITE, 64)
        } else {
            k2.draw_circle_outline(mouse_pos, max(f32(brush_thickness), 1), 1, brush_color, 64)
        }

        k2.present()
        free_all(context.temp_allocator)
    }

    save_whiteboard(file_path)
}

process_file :: proc(path: string) {
    world_pos := screen_to_world(k2.get_mouse_position())

	img, err := image.load_from_file(path, {.alpha_add_if_missing}, context.allocator)

	if err != nil {
		fmt.eprintf("Error loading texture '%v': %v", path, err)
		return
	}

    half := Vec2{f64(img.width), f64(img.height)} * 0.5 / camera.zoom

    shape := Shape{
        type      = .IMAGE,
        aabb_min  = world_pos - half,
        aabb_max  = world_pos + half,
        image     = img,
        texture   = k2.load_texture_from_bytes_raw(img.pixels.buf[:], img.width, img.height, .RGBA_8_Norm),
    }

    append(&shapes, shape)
}

// Roadmap
// - Text
// - Select copy paste
// - Graphs and Trees
