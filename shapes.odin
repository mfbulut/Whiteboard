package main

import "core:fmt"
import "core:math/linalg"

import k2 "karl2d"

Vec2 :: [2]f64

ShapeType :: enum {
	NORMAL,
	LINE,
	RECT,
    GRID,
}

Shape :: struct {
    type:      ShapeType,
    aabb_min:  Vec2,
    aabb_max:  Vec2,
    thickness: f64,
    color:     k2.Color,
    points:    [dynamic]Vec2,
}

shapes          : [dynamic]Shape
redo_queue      : [dynamic]Shape
brush_thickness : f64 = 3
brush_color     := k2.WHITE

STABILIZER_SAMPLES :: 8
stabilizer_buffer : [dynamic; STABILIZER_SAMPLES]Vec2

update_stabilizer :: proc(pos: Vec2) -> Vec2 {
    if len(stabilizer_buffer) + 1 > STABILIZER_SAMPLES {
        ordered_remove(&stabilizer_buffer, 0)
    }

    append(&stabilizer_buffer, pos)

    avg := Vec2{}
    total_weight : f64 = 0
    for p, i in stabilizer_buffer {
        weight := f64(i + 1)
        avg += p * weight
        total_weight += weight
    }
    return avg / total_weight
}

update_brush :: proc() {
    if k2.key_went_down(.N1) do brush_color = k2.WHITE
    if k2.key_went_down(.N2) do brush_color = k2.Color{219, 46, 0, 255}
    if k2.key_went_down(.N3) do brush_color = k2.Color{0, 138, 0, 255}
    if k2.key_went_down(.N4) do brush_color = k2.Color{0, 119, 255, 255}
    if k2.key_went_down(.N5) do brush_color = k2.Color{25, 198, 236, 255}
    if k2.key_went_down(.N6) do brush_color = k2.Color{255, 200, 50, 255}
    if k2.key_went_down(.N7) do brush_color = k2.Color{220, 50, 200, 255}

    if k2.key_is_held(.Left_Control) {
        brush_thickness = max(brush_thickness + f64(k2.get_mouse_wheel_delta()), 1)
    }

    if k2.key_is_held(.Left_Control) && k2.key_went_down(.Z) {
        if k2.key_is_held(.Left_Shift) {
            if shape, ok := pop_safe(&redo_queue); ok {
                append(&shapes, shape)
            }
        } else {
            if shape, ok := pop_safe(&shapes); ok {
                append(&redo_queue, shape)
            }
        }
    }

    update_stroke(.Left, brush_thickness  / camera.zoom, brush_color)
    update_stroke(.Right, brush_thickness / camera.zoom, BACKGROUND_COLOR)

    if k2.key_went_down(.R) {
        for shape in shapes do delete(shape.points)
        for shape in redo_queue do delete(shape.points)
        clear(&shapes)
        clear(&redo_queue)
        camera = Camera{
            zoom = 1e-8,
        }
        target_zoom = camera.zoom
        brush_thickness = 3
        brush_color = k2.WHITE
    }
}

update_stroke :: proc(button: k2.Mouse_Button, thickness: f64, color: k2.Color) {
    mouse_pos := Vec2(k2.get_mouse_position())
    mouse_world_pos := screen_to_world(mouse_pos)
    stable_world_pos := update_stabilizer(mouse_world_pos)

    if k2.mouse_button_went_down(button) {
        clear(&stabilizer_buffer)
        append(&stabilizer_buffer, mouse_world_pos)

        for len(redo_queue) > 0 {
            shape := pop(&redo_queue)
            delete(shape.points)
        }

        shape := Shape{
            points    = make([dynamic]Vec2, 0, 256),
            thickness = thickness,
            color     = color,
            aabb_min  = mouse_world_pos,
            aabb_max  = mouse_world_pos,
        }

        append(&shape.points, mouse_world_pos)

        if k2.key_is_held(.Left_Shift) {
            shape.type = .LINE
            append(&shape.points, mouse_world_pos)
        } else if k2.key_is_held(.Left_Control) {
            shape.type = .RECT
            append(&shape.points, mouse_world_pos, mouse_world_pos, mouse_world_pos, mouse_world_pos)
        } else if k2.key_is_held(.G) {
            shape.type = .GRID
            append(&shape.points, mouse_world_pos, mouse_world_pos)
        }

        append(&shapes, shape)
    }

    if k2.mouse_button_is_held(button) && len(shapes) > 0 {
        shape := &shapes[len(shapes) - 1]

        switch shape.type {
            case .NORMAL: {
                last := shape.points[len(shape.points) - 1]
                diff := (stable_world_pos - last) * camera.zoom
                if linalg.dot(diff, diff) < 4 do return

                if len(shape.points) == 1 {
                    append(&shape.points, mouse_world_pos)
                } else {
                    append(&shape.points, stable_world_pos)
                }
                shape.aabb_min = linalg.min(shape.aabb_min, stable_world_pos)
                shape.aabb_max = linalg.max(shape.aabb_max, stable_world_pos)
            }
            case .LINE, .GRID: {
                shape.points[1] = mouse_world_pos
                shape.aabb_min = linalg.min(shape.points[0], mouse_world_pos)
                shape.aabb_max = linalg.max(shape.points[0], mouse_world_pos)
            }
            case .RECT: {
                shape.points[1] = Vec2{mouse_world_pos.x, shape.points[0].y}
                shape.points[2] = mouse_world_pos
                shape.points[3] = Vec2{shape.points[0].x, mouse_world_pos.y}
                shape.aabb_min = linalg.min(shape.points[0], mouse_world_pos)
                shape.aabb_max = linalg.max(shape.points[0], mouse_world_pos)
            }
        }
    }
}

draw_shapes :: proc() {
    screen_size := Vec2{f64(k2.get_screen_width()), f64(k2.get_screen_height())}
    view_min := screen_to_world(Vec2{0, 0})
    view_max := screen_to_world(screen_size)

    for shape in shapes {
        if shape.aabb_max.x + shape.thickness < view_min.x ||
           shape.aabb_min.x - shape.thickness > view_max.x ||
           shape.aabb_max.y + shape.thickness < view_min.y ||
           shape.aabb_min.y - shape.thickness > view_max.y {
            continue
        }

        thickness := shape.thickness * camera.zoom
        segments := clamp(int(shape.thickness * camera.zoom * 2), 4, 64)

        switch shape.type {
            case .NORMAL: {
                points := screen_to_world(shape.points[:])
                draw_path(points[:], f32(thickness), shape.color, segments)
            }
            case .LINE, .RECT: {
                n := len(shape.points)

                if n > 0 {
                    prev := world_to_screen(shape.points[0])
                    k2.draw_circle(prev, f32(thickness), shape.color, segments)

                    for i in 1..<n {
                        next := world_to_screen(shape.points[i])
                        k2.draw_line(prev, next, f32(thickness) * 2, shape.color)
                        k2.draw_circle(next, f32(thickness), shape.color, segments)
                        prev = next
                    }
                }
            }
            case .GRID: {
                if len(shape.points) < 2 do break
                p0 := shape.points[0]
                p1 := shape.points[1]
                min_p := linalg.min(p0, p1)
                max_p := linalg.max(p0, p1)
                size  := max_p - min_p
                if size.x == 0 || size.y == 0 do break

                cell  := shape.thickness * 24
                cols  := max(int(size.x / cell), 1)
                rows  := max(int(size.y / cell), 1)

                grid_max := Vec2{min_p.x + f64(cols) * cell, min_p.y + f64(rows) * cell}

                thickness := shape.thickness * camera.zoom / 2
                segments  := clamp(int(thickness * 2), 4, 16)

                for i in 0..=cols {
                    x := min_p.x + f64(i) * cell
                    a := world_to_screen(Vec2{x, min_p.y})
                    b := world_to_screen(Vec2{x, grid_max.y})
                    k2.draw_line(a, b, f32(thickness) * 2, shape.color)
                }
                for i in 0..=rows {
                    y := min_p.y + f64(i) * cell
                    a := world_to_screen(Vec2{min_p.x, y})
                    b := world_to_screen(Vec2{grid_max.x, y})
                    k2.draw_line(a, b, f32(thickness) * 2, shape.color)
                }


                k2.draw_circle(world_to_screen(min_p), f32(thickness), shape.color, segments)
                k2.draw_circle(world_to_screen(min_p), f32(thickness), shape.color, segments)
            }
        }
    }
}

draw_path :: proc(points: []k2.Vec2, radius: f32, color: k2.Color, segments := 16) {
    points_len := len(points)
    if points_len < 2 {
        if points_len == 1 do k2.draw_circle(points[0], radius, color, segments)
        return
    }

    miter :: proc(a, b: k2.Vec2, radius: f32) -> (k2.Vec2, k2.Vec2) {
        n := linalg.normalize(b - a)
        perp := k2.Vec2{-n.y, n.x} * radius
        return a + perp, a - perp
    }

    prev_m0, prev_m1 := miter(points[0], points[1], radius)

    for i in 1 ..< points_len {
        next := points[min(i + 1, points_len - 1)]
        curr_m0, curr_m1 := miter(points[i], next, radius)

        if i == points_len - 1 {
            curr_m0, curr_m1 = miter(points[i - 1], points[i], radius)
            n := linalg.normalize(points[i] - points[i-1])
            perp := k2.Vec2{-n.y, n.x} * radius
            curr_m0 = points[i] + perp
            curr_m1 = points[i] - perp
        }

        k2.draw_triangle({prev_m0, prev_m1, curr_m0}, color)
        k2.draw_triangle({prev_m1, curr_m1, curr_m0}, color)

        prev_m0, prev_m1 = curr_m0, curr_m1
    }

    k2.draw_circle(points[0], radius, color, segments)
    k2.draw_circle(points[points_len - 1], radius, color, segments)
}