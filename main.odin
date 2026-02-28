package main

import "core:math/linalg"

import k2 "karl2d"

Vec2 :: [2]f64

Line :: struct {
    points:   [dynamic]Vec2,
    aabb_min: Vec2,
    aabb_max: Vec2,
    radius:   f64,
    color:    k2.Color,
}

BACKGROUND_COLOR :: k2.Color{22, 29, 50, 255}

lines: [dynamic]Line
brush_radius : f64 = 4
brush_color  := k2.WHITE
camera := Camera{zoom = 0.000001}

main :: proc() {
    k2.init(1280, 720, "Whiteboard", {.Windowed_Resizable})
    k2.set_cursor_visible(false)
    load_whiteboard()

    for k2.update() {
        update_camera()
        update_brush()

        if k2.key_went_down(.Z) {
            if len(lines) > 0 {
                delete(lines[len(lines) - 1].points)
                pop(&lines)
            }
        }

        if k2.key_went_down(.R) {
            for line in lines do delete(line.points)
            clear(&lines)
            camera = Camera{zoom = 0.000001}
            brush_radius = 4
        }

        k2.clear(BACKGROUND_COLOR)
        k2.set_camera(nil)

        screen_size := Vec2{f64(k2.get_screen_width()), f64(k2.get_screen_height())}
        view_min := screen_to_world({0, 0}, camera)
        view_max := screen_to_world(screen_size, camera)
        
        for line in lines {
            thickness := line.radius * camera.zoom
            
            if line.aabb_max.x + thickness < view_min.x ||
                line.aabb_min.x - thickness > view_max.x ||
                line.aabb_max.y + thickness < view_min.y ||
                line.aabb_min.y - thickness > view_max.y {
                continue
            }
            
            segments := clamp(int(line.radius * camera.zoom * 2), 4, 32)
            smoothed := smooth_path(line.points[:], segments / 4, context.temp_allocator)
            k2.draw_path(smoothed, f32(thickness), line.color, segments)

        }
        
        mouse_pos := k2.get_mouse_position()
        if k2.mouse_button_is_held(.Right) {
            k2.draw_circle_outline(mouse_pos, f32(brush_radius * 2), 2, k2.WHITE, 64)
        } else {
            k2.draw_circle_outline(mouse_pos, f32(brush_radius), 2, brush_color, 64)
        }

        k2.present()
    }

    save_whiteboard()
}

update_brush :: proc() {
    if k2.key_went_down(.N1) do brush_color = k2.WHITE
    if k2.key_went_down(.N2) do brush_color = k2.RED
    if k2.key_went_down(.N3) do brush_color = k2.GREEN
    if k2.key_went_down(.N4) do brush_color = k2.BLUE
    if k2.key_is_held(.Left_Control) {
        brush_radius = max(brush_radius + f64(k2.get_mouse_wheel_delta()), 1)
    }

    update_stroke(.Left, brush_radius / camera.zoom, brush_color)
    update_stroke(.Right, brush_radius * 2.0 / camera.zoom, BACKGROUND_COLOR)
}

start_pos: Vec2
drawing_line := false

update_stroke :: proc(button: k2.Mouse_Button, radius: f64, color: k2.Color) {
    mouse_pos := to_64(k2.get_mouse_position())
    mouse_world_pos := screen_to_world(mouse_pos, camera)

    if k2.mouse_button_went_down(button) {
        append(&lines, Line{
            points   = make([dynamic]Vec2, 0, 256),
            radius   = radius,
            color    = color,
            aabb_min = mouse_world_pos,
            aabb_max = mouse_world_pos,
        })
        append(&lines[len(lines) - 1].points, mouse_world_pos)

        start_pos    = mouse_world_pos
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

            append(&line.points, mouse_world_pos)
            line.aabb_min = linalg.min(line.aabb_min, mouse_world_pos)
            line.aabb_max = linalg.max(line.aabb_max, mouse_world_pos)
        }
    }
}

smooth_path :: proc(points: []Vec2, subdivisions := 16, allocator := context.allocator) -> []k2.Vec2 {
    n := len(points)
    
    if n == 0 do return {}
    
    catmull_rom :: proc(p0, p1, p2, p3: Vec2, t: f64) -> Vec2 {
        t2, t3 := t * t, t * t * t
        return 0.5 * (
            2.0 * p1 +
            (-p0 + p2) * t +
            (2.0*p0 - 5.0*p1 + 4.0*p2 - p3) * t2 +
            (-p0 + 3.0*p1 - 3.0*p2 + p3) * t3
        )
    }

    total  := (n - 1) * subdivisions + 1
    result := make([]k2.Vec2, total, allocator)

    idx := 0
    for i in 0 ..< n - 1 {
        cp0 := points[max(i - 1, 0)]
        cp1 := points[i]
        cp2 := points[i + 1]
        cp3 := points[min(i + 2, n - 1)]

        for sub in 0 ..< subdivisions {
            t := f64(sub) / f64(subdivisions)
            p := catmull_rom(cp0, cp1, cp2, cp3, t)
            result[idx] = world_to_screen(p, camera)
            idx += 1
        }
    }

    result[idx] = world_to_screen(points[n - 1], camera)
    return result
}