package main

import "core:fmt"
import "core:mem"
import "core:os"
import "core:reflect"
import "base:runtime"

save :: proc(filepath: string, args: ..any) {
    buf := make([dynamic]byte, 0, 1024, context.allocator)
    defer delete(buf)

    for arg in args {
        serialize_value(&buf, arg)
    }

    _ = os.write_entire_file(filepath, buf[:])
}

load :: proc(filepath: string, args: ..any) {
    data, err := os.read_entire_file(filepath, context.allocator)
    if err != nil do return
    defer delete(data)

    cursor := 0
    for arg in args {
        ptr_info := reflect.type_info_base(type_info_of(arg.id))
        pi, is_ptr := ptr_info.variant.(runtime.Type_Info_Pointer)
        assert(is_ptr, "load: all arguments must be pointers")

        inner_ptr := (^rawptr)(arg.data)^
        deserialize_value(data, &cursor, any{inner_ptr, pi.elem.id})
    }
}

serialize_value :: proc(buf: ^[dynamic]byte, v: any) {
    ti := reflect.type_info_base(type_info_of(v.id))

    #partial switch info in ti.variant {

    case runtime.Type_Info_Integer,
         runtime.Type_Info_Float,
         runtime.Type_Info_Boolean,
         runtime.Type_Info_Enum:
        raw := mem.byte_slice(v.data, ti.size)
        append(buf, ..raw)

    case runtime.Type_Info_Array:
        for i in 0 ..< info.count {
            elem_ptr := rawptr(uintptr(v.data) + uintptr(i) * uintptr(info.elem_size))
            serialize_value(buf, any{elem_ptr, info.elem.id})
        }

    case runtime.Type_Info_Dynamic_Array:
        raw_da := (^runtime.Raw_Dynamic_Array)(v.data)
        length := raw_da.len

        len_bytes := mem.byte_slice(&length, size_of(int))
        append(buf, ..len_bytes)

        for i in 0 ..< length {
            elem_ptr := rawptr(uintptr(raw_da.data) + uintptr(i) * uintptr(info.elem_size))
            serialize_value(buf, any{elem_ptr, info.elem.id})
        }

    case runtime.Type_Info_Slice:
        raw_sl := (^runtime.Raw_Slice)(v.data)
        length  := raw_sl.len

        len_bytes := mem.byte_slice(&length, size_of(int))
        append(buf, ..len_bytes)

        for i in 0 ..< length {
            elem_ptr := rawptr(uintptr(raw_sl.data) + uintptr(i) * uintptr(info.elem_size))
            serialize_value(buf, any{elem_ptr, info.elem.id})
        }

    case runtime.Type_Info_Struct:
        for i in 0 ..< info.field_count {
            field_ptr := rawptr(uintptr(v.data) + uintptr(info.offsets[i]))
            serialize_value(buf, any{field_ptr, info.types[i].id})
        }

    case:
        fmt.panicf("serialize: unsupported type %v", ti)
    }
}

deserialize_value :: proc(data: []byte, cursor: ^int, v: any) {
    ti := reflect.type_info_base(type_info_of(v.id))

    #partial switch info in ti.variant {

    case runtime.Type_Info_Integer,
         runtime.Type_Info_Float,
         runtime.Type_Info_Boolean,
         runtime.Type_Info_Enum:
        size := ti.size
        assert(cursor^ + size <= len(data), "deserialize: buffer underrun (numeric)")
        mem.copy(v.data, &data[cursor^], size)
        cursor^ += size

    case runtime.Type_Info_Array:
        for i in 0 ..< info.count {
            elem_ptr := rawptr(uintptr(v.data) + uintptr(i) * uintptr(info.elem_size))
            deserialize_value(data, cursor, any{elem_ptr, info.elem.id})
        }

    case runtime.Type_Info_Dynamic_Array:
        assert(cursor^ + size_of(int) <= len(data), "deserialize: buffer underrun (dyn array len)")
        length: int
        mem.copy(&length, &data[cursor^], size_of(int))
        cursor^ += size_of(int)

        raw_da := (^runtime.Raw_Dynamic_Array)(v.data)
        runtime.__dynamic_array_resize(raw_da, info.elem_size, info.elem.align, length)

        for i in 0 ..< length {
            elem_ptr := rawptr(uintptr(raw_da.data) + uintptr(i) * uintptr(info.elem_size))
            deserialize_value(data, cursor, any{elem_ptr, info.elem.id})
        }

    case runtime.Type_Info_Slice:
        assert(cursor^ + size_of(int) <= len(data), "deserialize: buffer underrun (slice len)")
        length: int
        mem.copy(&length, &data[cursor^], size_of(int))
        cursor^ += size_of(int)

        raw_sl := (^runtime.Raw_Slice)(v.data)
        raw_sl.data, _ = mem.alloc(length * info.elem_size, info.elem.align)
        raw_sl.len  = length

        for i in 0 ..< length {
            elem_ptr := rawptr(uintptr(raw_sl.data) + uintptr(i) * uintptr(info.elem_size))
            deserialize_value(data, cursor, any{elem_ptr, info.elem.id})
        }

    case runtime.Type_Info_Struct:
        for i in 0 ..< info.field_count {
            field_ptr := rawptr(uintptr(v.data) + uintptr(info.offsets[i]))
            deserialize_value(data, cursor, any{field_ptr, info.types[i].id})
        }

    case:
        fmt.panicf("deserialize: unsupported type %v", ti)
    }
}

