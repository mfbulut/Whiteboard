package main

import "core:fmt"
import "core:math/linalg"

import k2 "karl2d"

Line :: struct {
    points:   [dynamic]k2.Vec2,
    aabb_max: k2.Vec2,
    aabb_min: k2.Vec2,
    color:    k2.Color,
    radius:   f32,
}

lines: [dynamic]Line
brush_color  := k2.WHITE
brush_radius : f32 = 4
camera := k2.Camera{zoom = 0.000001}

BACKGROUND_COLOR :: k2.Color{22, 29, 50, 255}

main :: proc() {
    k2.init(1280, 720, "Whiteboard", {.Windowed_Resizable})
    k2.set_cursor_visible(false)
    
    load_whiteboard()

    for k2.update() {
        update_camera()
        update_brush()

        // TODO: Add redo
        if k2.key_went_down(.Z) {
            if len(lines) > 0 {
                delete(lines[len(lines) - 1].points)
                pop(&lines)
            }
        }

        if k2.key_went_down(.C) {
            for line in lines do delete(line.points)
            clear(&lines)
            camera = k2.Camera{zoom = 0.000001}
        }

        k2.clear(BACKGROUND_COLOR)
        k2.set_camera(camera)

        screen_size := k2.Vec2{f32(k2.get_screen_width()), f32(k2.get_screen_height())}
        view_min := k2.screen_to_world({0, 0}, camera)
        view_max := k2.screen_to_world(screen_size, camera)

        for line in lines {
            if line.aabb_max.x + line.radius < view_min.x || line.aabb_min.x - line.radius > view_max.x do continue
            if line.aabb_max.y + line.radius < view_min.y || line.aabb_min.y - line.radius > view_max.y do continue
            
            segments := clamp(int(line.radius * camera.zoom * 2), 4, 32)
           
            smoothed := smooth_path(line.points[:], segments / 4, context.temp_allocator)
            k2.draw_path(smoothed, line.radius, line.color, segments)
        }

        k2.set_camera(nil)

        mouse_pos := k2.get_mouse_position()
        if k2.mouse_button_is_held(.Right) {
            k2.draw_circle_outline(mouse_pos, brush_radius * 2, 2, k2.WHITE, 64)
        } else {
            k2.draw_circle_outline(mouse_pos, brush_radius, 2, brush_color, 64)
        }
        
        k2.present()
    }
    
    save_whiteboard()
}

update_camera :: proc() {
    mouse_pos := k2.get_mouse_position()

    if !k2.key_is_held(.Left_Control) {
        wheel := k2.get_mouse_wheel_delta()
        if wheel != 0 {
            old_zoom := camera.zoom
            camera.zoom = old_zoom * (1.0 + wheel * 0.1)
            camera.target += mouse_pos * (1.0 / old_zoom - 1.0 / camera.zoom)
            
            if k2.key_is_held(.Left_Shift) {
                brush_radius *= camera.zoom / old_zoom
            }
        }
    }

    if k2.mouse_button_is_held(.Middle) || k2.key_is_held(.Space) {
        delta := k2.get_mouse_delta()
        if delta.x != 0 || delta.y != 0 {
            camera.target += delta / -camera.zoom
        }
    }
}

update_brush :: proc() {
    if k2.key_went_down(.N1) do brush_color = k2.WHITE
    if k2.key_went_down(.N2) do brush_color = k2.RED
    if k2.key_went_down(.N3) do brush_color = k2.GREEN
    if k2.key_went_down(.N4) do brush_color = k2.BLUE
    if k2.key_is_held(.Left_Control) {
        brush_radius = max(brush_radius + k2.get_mouse_wheel_delta(), 1)
    }
    
    update_stroke(.Left, brush_radius / camera.zoom, brush_color)
    update_stroke(.Right, brush_radius * 2.0 / camera.zoom, BACKGROUND_COLOR)
}


// TODO: Find a better way to draw shapes
start_pos: k2.Vec2
drawing_line := false

update_stroke :: proc(button: k2.Mouse_Button, radius: f32, color: k2.Color) {
    mouse_world_pos := k2.screen_to_world(k2.get_mouse_position(), camera)

    if k2.mouse_button_went_down(button) {
        append(&lines, Line{
            points   = make([dynamic]k2.Vec2, 0, 256),
            radius   = radius,
            color    = color,
            aabb_min = mouse_world_pos,
            aabb_max = mouse_world_pos,
        })
        append(&lines[len(lines) - 1].points, mouse_world_pos)
        
        start_pos = mouse_world_pos
        drawing_line = k2.key_is_held(.Left_Shift) || k2.key_is_held(.Right_Shift)
    }

    if k2.mouse_button_is_held(button) && len(lines) > 0 {
        line := &lines[len(lines) - 1]

        if drawing_line {
            clear(&line.points)
            append(&line.points, start_pos)
            append(&line.points, mouse_world_pos)
            line.aabb_min = linalg.min(start_pos, mouse_world_pos)
            line.aabb_max = linalg.max(start_pos, mouse_world_pos)
        } else {
            last := line.points[len(line.points) - 1]
            diff := (mouse_world_pos - last) * camera.zoom
            if linalg.dot(diff, diff) < 5 do return

            // Todo: Smooth jitter from mouse
            append(&line.points, mouse_world_pos)
            line.aabb_min = linalg.min(line.aabb_min, mouse_world_pos)
            line.aabb_max = linalg.max(line.aabb_max, mouse_world_pos)
        }
    }
}

smooth_path :: proc(points: []k2.Vec2, subdivisions := 16, allocator := context.allocator) -> []k2.Vec2 {
    points_len := len(points)
    if points_len < 2 do return points[:]

    catmull_rom :: proc(p0, p1, p2, p3: k2.Vec2, t: f32) -> k2.Vec2 {
        t2, t3 := t * t, t * t * t
        return 0.5 * (
            2.0 * p1 +
            (-p0 + p2) * t +
            (2.0*p0 - 5.0*p1 + 4.0*p2 - p3) * t2 +
            (-p0 + 3.0*p1 - 3.0*p2 + p3) * t3
        )
    }

    total := (points_len - 1) * subdivisions + 1
    result := make([]k2.Vec2, total, allocator)

    idx := 0
    for i in 0 ..< points_len - 1 {
        cp0 := points[max(i - 1, 0)]
        cp1 := points[i]
        cp2 := points[i + 1]
        cp3 := points[min(i + 2, points_len - 1)]

        for sub in 0 ..< subdivisions {
            t := f32(sub) / f32(subdivisions)
            result[idx] = catmull_rom(cp0, cp1, cp2, cp3, t)
            idx += 1
        }
    }
    
    result[idx] = points[points_len - 1]

    return result
}