package main

import "core:os"
import "core:bytes"

import k2 "karl2d"

save_whiteboard :: proc(filepath: string) {
    buf := make([dynamic]byte, 0, 1024, context.allocator)

    append_val :: proc(buf: ^[dynamic]byte, v: $T) {
        data := transmute([size_of(T)]byte)v
        append(buf, ..data[:])
    }

    append_val(&buf, camera)
    append_val(&buf, brush_thickness)
    append_val(&buf, brush_color)
    append_val(&buf, u32(len(shapes)))

    for shape in shapes {
        append_val(&buf, shape.type)
        append_val(&buf, shape.aabb_min)
        append_val(&buf, shape.aabb_max)
        append_val(&buf, shape.thickness)
        append_val(&buf, shape.color)
        append_val(&buf, u32(len(shape.points)))
        for p in shape.points do append_val(&buf, p)
    }

    _ = os.write_entire_file(filepath, buf[:])
}

load_whiteboard :: proc(filepath: string) {
    data, err := os.read_entire_file(filepath, context.allocator)
    if err != nil do return

    pos := 0
    read :: proc(data: []byte, pos: ^int, $T: typeid) -> T {
        v := (cast(^T)&data[pos^])^
        pos^ += size_of(T)
        return v
    }

    camera          = read(data, &pos, Camera)
    target_zoom     = camera.zoom
    brush_thickness = read(data, &pos, f64)
    brush_color     = read(data, &pos, k2.Color)
    num_shapes     := read(data, &pos, u32)

    for _ in 0..<num_shapes {
        type      := read(data, &pos, ShapeType)
        aabb_min  := read(data, &pos, Vec2)
        aabb_max  := read(data, &pos, Vec2)
        thickness := read(data, &pos, f64)
        color     := read(data, &pos, k2.Color)
        num_pts   := read(data, &pos, u32)

        points := make([dynamic]Vec2, 0, num_pts)
        for _ in 0..<num_pts {
            p := read(data, &pos, Vec2)
            append(&points, p)
        }

        append(&shapes, Shape{type, aabb_min, aabb_max, thickness, color, points})
    }
}
