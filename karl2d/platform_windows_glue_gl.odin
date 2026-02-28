// Glues together OpenGL with a Windows window. This is done by making a WGL context and using it
// to SwapBuffers etc.
#+build windows
#+private file
package karl2d

import win32 "core:sys/windows"
import gl "vendor:OpenGL"
import "base:runtime"
import "log"

@(private="package")
make_windows_gl_glue :: proc(
	hwnd: win32.HWND,
	allocator: runtime.Allocator,
	loc := #caller_location
) -> Window_Render_Glue {
	state := new(Windows_GL_Glue_State, allocator, loc)
	state.hwnd = hwnd
	state.allocator = allocator
	return {
		state = (^Window_Render_Glue_State)(state),

		// these casts just make the proc take a Windows_GL_Glue_State instead of a Window_Render_Glue_State
		make_context = cast(proc(state: ^Window_Render_Glue_State) -> bool)(windows_gl_glue_make_context),
		present = cast(proc(state: ^Window_Render_Glue_State))(windows_gl_glue_present),
		destroy = cast(proc(state: ^Window_Render_Glue_State))(windows_gl_glue_destroy),
		viewport_resized = cast(proc(state: ^Window_Render_Glue_State))(windows_gl_glue_viewport_resized),
	}
}

Windows_GL_Glue_State :: struct {
	hwnd: win32.HWND,
	gl_ctx: win32.HGLRC,
	device_ctx: win32.HDC,
	allocator: runtime.Allocator,
}
windows_gl_glue_make_context :: proc(s: ^Windows_GL_Glue_State) -> bool {
    // ── Step 1: dummy window just to load WGL extension procs ──────────────
    dummy_hwnd := win32.CreateWindowExW(
        0,
        win32.L("STATIC"),
        win32.L("dummy"),
        win32.WS_OVERLAPPED,
        0, 0, 1, 1,
        nil, nil, nil, nil,
    )
    if dummy_hwnd == nil {
        log.error("Failed to create dummy window")
        return false
    }
    defer win32.DestroyWindow(dummy_hwnd)

    dummy_dc := win32.GetDC(dummy_hwnd)
    defer win32.ReleaseDC(dummy_hwnd, dummy_dc)

    dummy_pfd := win32.PIXELFORMATDESCRIPTOR {
        nSize      = size_of(win32.PIXELFORMATDESCRIPTOR),
        nVersion   = 1,
        dwFlags    = win32.PFD_DRAW_TO_WINDOW | win32.PFD_SUPPORT_OPENGL | win32.PFD_DOUBLEBUFFER,
        iPixelType = win32.PFD_TYPE_RGBA,
        cColorBits = 32,
        iLayerType = win32.PFD_MAIN_PLANE,
    }
    dummy_fmt := win32.ChoosePixelFormat(dummy_dc, &dummy_pfd)
    win32.SetPixelFormat(dummy_dc, dummy_fmt, &dummy_pfd)

    dummy_ctx := win32.wglCreateContext(dummy_dc)
    if dummy_ctx == nil {
        log.error("Failed to create dummy GL context")
        return false
    }
    win32.wglMakeCurrent(dummy_dc, dummy_ctx)

    // Load WGL extension procs from the dummy context
    win32.gl_set_proc_address(&win32.wglChoosePixelFormatARB,    "wglChoosePixelFormatARB")
    win32.gl_set_proc_address(&win32.wglCreateContextAttribsARB, "wglCreateContextAttribsARB")
    win32.gl_set_proc_address(&win32.wglSwapIntervalEXT,         "wglSwapIntervalEXT")

    win32.wglMakeCurrent(nil, nil)
    win32.wglDeleteContext(dummy_ctx)

    if win32.wglChoosePixelFormatARB == nil {
        log.error("Failed fetching wglChoosePixelFormatARB")
        return false
    }
    if win32.wglCreateContextAttribsARB == nil {
        log.error("Failed fetching wglCreateContextAttribsARB")
        return false
    }
    if win32.wglSwapIntervalEXT == nil {
        log.error("Failed fetching wglSwapIntervalEXT")
        return false
    }

    // ── Step 2: now set up the REAL DC on the actual window ────────────────
    s.device_ctx = win32.GetWindowDC(s.hwnd)

    pixel_format_ilist := [?]i32 {
        win32.WGL_DRAW_TO_WINDOW_ARB, 1,
        win32.WGL_SUPPORT_OPENGL_ARB, 1,
        win32.WGL_DOUBLE_BUFFER_ARB,  1,
        win32.WGL_PIXEL_TYPE_ARB,     win32.WGL_TYPE_RGBA_ARB,
        win32.WGL_COLOR_BITS_ARB,     32,
        win32.WGL_SAMPLE_BUFFERS_ARB, 1,
        win32.WGL_SAMPLES_ARB,        8,
        0,
    }

    pixel_format: i32
    num_formats:  u32
    ok := win32.wglChoosePixelFormatARB(
        s.device_ctx,
        raw_data(pixel_format_ilist[:]),
        nil, 1,
        &pixel_format, &num_formats,
    )
    if !ok || num_formats == 0 {
        log.error("wglChoosePixelFormatARB failed")
        return false
    }

    // First and only SetPixelFormat call on the real DC — this one sticks
    win32.SetPixelFormat(s.device_ctx, pixel_format, nil)

    ctx_attribs := [?]i32 {
        win32.WGL_CONTEXT_MAJOR_VERSION_ARB, 3,
        win32.WGL_CONTEXT_MINOR_VERSION_ARB, 3,
        win32.WGL_CONTEXT_PROFILE_MASK_ARB,  win32.WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
        0,
    }
    s.gl_ctx = win32.wglCreateContextAttribsARB(s.device_ctx, nil, raw_data(ctx_attribs[:]))
    if s.gl_ctx == nil {
        log.error("wglCreateContextAttribsARB failed")
        return false
    }

    win32.wglMakeCurrent(s.device_ctx, s.gl_ctx)
    win32.wglSwapIntervalEXT(1)

    gl.load_up_to(3, 3, win32.gl_set_proc_address)

    return true
}

windows_gl_glue_present :: proc(s: ^Windows_GL_Glue_State) {
	win32.SwapBuffers(s.device_ctx)
}

windows_gl_glue_destroy :: proc(s: ^Windows_GL_Glue_State) {
	win32.wglDeleteContext(s.gl_ctx)
	a := s.allocator
	free(s, a)
}

windows_gl_glue_viewport_resized :: proc(s: ^Windows_GL_Glue_State) {
}