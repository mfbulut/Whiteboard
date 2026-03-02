package main

import "core:os"
import "core:path/filepath"

import k2 "karl2d"

get_whiteboard_path :: proc() -> string {
    docs, _ := os.user_documents_dir(context.allocator)
    file_path, _ := filepath.join({docs, "whiteboard.bin"}, context.allocator)
    return file_path
}

save_whiteboard :: proc() {
    path := get_whiteboard_path()
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
        append_val(&buf, shape.color)
        append_val(&buf, shape.thickness)
        append_val(&buf, shape.aabb_min)
        append_val(&buf, shape.aabb_max)
        append_val(&buf, shape.type)
        append_val(&buf, u32(len(shape.points)))
        for p in shape.points do append_val(&buf, p)
    }

    _ = os.write_entire_file(path, buf[:])
}

load_whiteboard :: proc() -> bool {
    path := get_whiteboard_path()
    data, err := os.read_entire_file(path, context.allocator)
    defer delete(data)
    if err != nil do return false

    pos := 0
    read :: proc(data: []byte, pos: ^int, $T: typeid) -> (v: T, ok: bool) {
        if pos^ + size_of(T) > len(data) do return
        v = (cast(^T)&data[pos^])^
        pos^ += size_of(T)
        ok = true
        return
    }

    camera          = read(data, &pos, Camera)    or_return
    target_zoom     = camera.zoom
    brush_thickness = read(data, &pos, f64)       or_return
    brush_color     = read(data, &pos, k2.Color)  or_return
    num_shapes      := read(data, &pos, u32)      or_return

    for _ in 0..<num_shapes {
        color     := read(data, &pos, k2.Color)  or_return
        thickness := read(data, &pos, f64)       or_return
        aabb_min  := read(data, &pos, Vec2)      or_return
        aabb_max  := read(data, &pos, Vec2)      or_return
        type      := read(data, &pos, ShapeType) or_return
        num_pts   := read(data, &pos, u32)       or_return
        
        points := make([dynamic]Vec2, 0, num_pts)
        for _ in 0..<num_pts {
            p := read(data, &pos, Vec2) or_return
            append(&points, p)
        }
        append(&shapes, Shape{points, aabb_min, aabb_max, thickness, color, type})
    }


    return true
}