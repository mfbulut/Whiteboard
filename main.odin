package main

import "core:fmt"
import "core:math/linalg"

import k2 "karl2d"

Vec2 :: [2]f64

BACKGROUND_COLOR :: k2.Color{22, 29, 50, 255}

process_file :: proc(path: string) {
    world_pos := screen_to_world(to_64(k2.get_mouse_position()), camera)

    tex := k2.load_texture_from_file(path)
    if tex.width == 0 || tex.height == 0 {
        fmt.eprintln("Failed to load image:", path)
        return
    }

    half := Vec2{f64(tex.width), f64(tex.height)} * 0.5 / camera.zoom

    shape := Shape{
        type      = .IMAGE,
        image     = tex,
        aabb_min  = world_pos - half,
        aabb_max  = world_pos + half,
    }
    
    append(&shapes, shape)
}

main :: proc() {
    k2.init(1280, 720, "Whiteboard", {.Windowed_Resizable})
    k2.windows_set_file_drop_callback(process_file)
    k2.set_cursor_visible(false)
    
    load_whiteboard()
    
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
            k2.draw_circle(mouse_pos, max(f32(brush_thickness), 1), k2.WHITE, 64)
        } else if k2.mouse_button_is_held(.Right) {
            k2.draw_circle_outline(mouse_pos, max(f32(brush_thickness), 1), 1, k2.WHITE, 64)
        } else {
            k2.draw_circle_outline(mouse_pos, max(f32(brush_thickness), 1), 1, brush_color, 64)
        }

        k2.present()
        free_all(context.temp_allocator)
    }

    save_whiteboard()
}

// Roadmap
// - Save / Load Images
// - Text
// - Graphs and Trees
// - Select copy paste