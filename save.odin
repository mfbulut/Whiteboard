package main
import k2 "karl2d"
import "core:os"
import "core:path/filepath"
import "core:mem"

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
    append_val(&buf, brush_color)
    append_val(&buf, brush_radius)
    append_val(&buf, u32(len(lines)))

    for line in lines {
        append_val(&buf, line.color)
        append_val(&buf, line.radius)
        append_val(&buf, line.aabb_min)
        append_val(&buf, line.aabb_max)
        append_val(&buf, u32(len(line.points)))
        for p in line.points do append_val(&buf, p)
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

    camera       = read(data, &pos, k2.Camera) or_return
    brush_color  = read(data, &pos, k2.Color)  or_return
    brush_radius = read(data, &pos, f32)       or_return
    num_lines   := read(data, &pos, u32)       or_return

    for _ in 0..<num_lines {
        color    := read(data, &pos, k2.Color) or_return
        radius   := read(data, &pos, f32)      or_return
        aabb_min := read(data, &pos, k2.Vec2)  or_return
        aabb_max := read(data, &pos, k2.Vec2)  or_return
        num_pts  := read(data, &pos, u32)      or_return
        points := make([dynamic]k2.Vec2, 0, num_pts)
        for _ in 0..<num_pts {
            p := read(data, &pos, k2.Vec2) or_return
            append(&points, p)
        }
        append(&lines, Line{points, aabb_min, aabb_max, color, radius})
    }

    return true
}