package main

import "core:fmt"
import "core:math/linalg"

import k2 "karl2d"

ShapeType :: enum {
	NORMAL,
	LINE,
	RECT,
    GRID,
}

Shape :: struct {
    type:      ShapeType,
    aabb_min:  k2.Vec2,
    aabb_max:  k2.Vec2,
    thickness: f32,
    color:     k2.Color,
    points:    [dynamic]k2.Vec2,
}

shapes          : [dynamic]Shape
redo_queue      : [dynamic]Shape
brush_thickness := f32(3)
brush_color     := k2.WHITE

STABILIZER_SAMPLES :: 8
stabilizer_buffer : [dynamic; STABILIZER_SAMPLES]k2.Vec2

update_stabilizer :: proc(pos: k2.Vec2) -> k2.Vec2 {
    if len(stabilizer_buffer) >= STABILIZER_SAMPLES {
        ordered_remove(&stabilizer_buffer, 0)
    }

    append(&stabilizer_buffer, pos)

    avg : k2.Vec2
    total_weight : f32
    for p, i in stabilizer_buffer {
        weight := f32(i + 1)
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

    if k2.key_is_held(.Left_Control) || k2.key_is_held(.Left_Shift) || k2.key_is_held(.G) {
        brush_thickness = max(brush_thickness + k2.get_mouse_wheel_delta(), 1)
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

    update_stroke(.Left, brush_thickness / camera.zoom, brush_color)
    update_stroke(.Right, brush_thickness / camera.zoom, BACKGROUND_COLOR)

    if k2.key_went_down(.R) {
        for shape in shapes do delete(shape.points)
        for shape in redo_queue do delete(shape.points)
        clear(&shapes)
        clear(&redo_queue)
        camera = k2.Camera{
            zoom = 1,
        }
        target_zoom = camera.zoom
        brush_thickness = 3
        brush_color = k2.WHITE
    }
}

update_stroke :: proc(button: k2.Mouse_Button, thickness: f32, color: k2.Color) {
    mouse_pos := k2.get_mouse_position()
    mouse_world_pos := k2.screen_to_world(mouse_pos, camera)
    stable_world_pos := update_stabilizer(mouse_world_pos)

    if k2.mouse_button_went_down(button) {
        clear(&stabilizer_buffer)
        append(&stabilizer_buffer, mouse_world_pos)

        for len(redo_queue) > 0 {
            shape := pop(&redo_queue)
            delete(shape.points)
        }

        shape := Shape{
            points    = make([dynamic]k2.Vec2, 0, 256),
            thickness = thickness,
            color     = color,
            aabb_min  = mouse_world_pos,
            aabb_max  = mouse_world_pos,
        }

        append(&shape.points, mouse_world_pos)

        if k2.key_is_held(.Left_Shift) {
            // Extend existing line if last shape is a LINE
            if len(shapes) > 0 && shapes[len(shapes) - 1].type == .LINE {
                last := &shapes[len(shapes) - 1]
                append(&last.points, mouse_world_pos)
                last.aabb_min = linalg.min(last.aabb_min, mouse_world_pos)
                last.aabb_max = linalg.max(last.aabb_max, mouse_world_pos)
                delete(shape.points)
                return
            }
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
                last := k2.world_to_screen(shape.points[len(shape.points) - 1], camera)
                diff := mouse_world_pos - last
                if linalg.dot(diff, diff) < 4 do return

                if len(shape.points) == 1 {
                    append(&shape.points, mouse_world_pos)
                } else {
                    append(&shape.points, stable_world_pos)
                }
                shape.aabb_min  = linalg.min(shape.aabb_min, stable_world_pos)
                shape.aabb_max  = linalg.max(shape.aabb_max, stable_world_pos)
                shape.thickness = thickness
            }
            case .LINE: {
                shape.points[len(shape.points) - 1] = mouse_world_pos
                shape.aabb_min = shape.points[0]
                shape.aabb_max = shape.points[0]
                for p in shape.points[1:] {
                    shape.aabb_min = linalg.min(shape.aabb_min, p)
                    shape.aabb_max = linalg.max(shape.aabb_max, p)
                }
                shape.thickness = thickness
                shape.color     = brush_color
            }
            case .GRID: {
                shape.points[1] = mouse_world_pos
                shape.aabb_min  = linalg.min(shape.points[0], mouse_world_pos)
                shape.aabb_max  = linalg.max(shape.points[0], mouse_world_pos)
                shape.thickness = thickness
                shape.color     = brush_color
            }
            case .RECT: {
                shape.points[1] = k2.Vec2{mouse_world_pos.x, shape.points[0].y}
                shape.points[2] = mouse_world_pos
                shape.points[3] = k2.Vec2{shape.points[0].x, mouse_world_pos.y}
                shape.aabb_min  = linalg.min(shape.points[0], mouse_world_pos)
                shape.aabb_max  = linalg.max(shape.points[0], mouse_world_pos)
                shape.thickness = thickness
                shape.color     = brush_color
            }
        }
    }
}

draw_shapes :: proc() {
    screen_size := k2.get_screen_size()
    view_min := k2.screen_to_world({0, 0}, camera)
    view_max := k2.screen_to_world(screen_size, camera)

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
                points := make([]k2.Vec2, len(shape.points), context.temp_allocator)

                for &p, i in points {
                    p = k2.world_to_screen(shape.points[i], camera)
                }

                draw_path(points[:], f32(thickness), shape.color, segments)
            }
            case .LINE, .RECT: {
                n := len(shape.points)

                if n > 0 {
                    prev := k2.world_to_screen(shape.points[0], camera)
                    k2.draw_circle(prev, f32(thickness), shape.color, segments)

                    for i in 1..<n {
                        next := k2.world_to_screen(shape.points[i], camera)
                        k2.draw_line(prev, next, f32(thickness) * 2, shape.color)
                        k2.draw_circle(next, f32(thickness), shape.color, segments)
                        prev = next
                    }
                }
            }
            case .GRID: {
                p0 := shape.points[0]
                p1 := shape.points[1]
                dx := p1.x - p0.x
                dy := p1.y - p0.y

                cell  := shape.thickness * 30
                cols  := max(int(abs(dx) / cell), 1)
                rows  := max(int(abs(dy) / cell), 1)

                grid_min : k2.Vec2
                grid_min.x = dx >= 0 ? p0.x : p0.x - f32(cols) * cell
                grid_min.y = dy >= 0 ? p0.y : p0.y - f32(rows) * cell
                grid_max := k2.Vec2{grid_min.x + f32(cols) * cell, grid_min.y + f32(rows) * cell}
                segments  := clamp(int(thickness * 2), 4, 16)

                for i in 0..=cols {
                    x := grid_min.x + f32(i) * cell
                    a := k2.world_to_screen({x, grid_min.y - shape.thickness}, camera)
                    b := k2.world_to_screen({x, grid_max.y + shape.thickness}, camera)
                    k2.draw_line(a, b, thickness * 2, shape.color)
                }
                for i in 0..=rows {
                    y := grid_min.y + f32(i) * cell
                    a := k2.world_to_screen({grid_min.x - shape.thickness, y}, camera)
                    b := k2.world_to_screen({grid_max.x + shape.thickness, y}, camera)
                    k2.draw_line(a, b, thickness * 2, shape.color)
                }
            }
        }
    }
}

draw_path :: proc(points: []k2.Vec2, radius: f32, color: k2.Color, segments := 16) {
    n := len(points)

    if n < 2 {
        if n == 1 do k2.draw_circle(points[0], radius, color, segments)
        return
    }

    miter :: proc(a, b: k2.Vec2, radius: f32) -> (k2.Vec2, k2.Vec2) {
        n := linalg.normalize(b - a)
        perp := k2.Vec2{-n.y, n.x} * radius
        return a + perp, a - perp
    }

    prev_m0, prev_m1 := miter(points[0], points[1], radius)

    for i in 1..<n {
        next := points[min(i + 1, n - 1)]
        curr_m0, curr_m1 := miter(points[i], next, radius)

        if i == n - 1 {
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
    k2.draw_circle(points[n - 1], radius, color, segments)
}