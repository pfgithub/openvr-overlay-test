const std = @import("std");

const c = @cImport({
    @cInclude("GL/gl.h");
    @cDefine("CNFGOGL", "");
    @cInclude("rawdraw_sf.h");
    @cInclude("openvr_undef.h");
    @cInclude("openvr_capi.h");
    @cInclude("openvr_globalentrypoints.h");
});

export fn HandleKey(keycode: c_int, b_down: c_int) callconv(.C) void {
    _ = keycode; _ = b_down;
    //
}
export fn HandleButton(x: c_int, y: c_int, button: c_int, b_down: c_int) callconv(.C) void {
    _ = x; _ = y; _ = button; _ = b_down;
    //
}
export fn HandleMotion(x: c_int, y: c_int, mask: c_int) callconv(.C) void {
    _ = x; _ = y; _ = mask;
}
export fn HandleDestroy() callconv(.C) void {}

fn CNOVRGetOpenVRFunctionTable(
    comptime ReturnType: type,
    interfacename: [*c]const u8,
) !ReturnType {
    var e: c.EVRInitError = undefined;
    const alloc = std.heap.c_allocator;

    const printed = try std.fmt.allocPrintZ(alloc, "FnTable:{s}", .{std.mem.span(interfacename)});
    defer alloc.free(printed);

    const ret = @bitCast(usize, c.VR_GetGenericInterface(printed.ptr, &e));
    std.log.info("Getting System {s} = {} ({d})", .{printed, ret, e});
    if(ret == 0) return error.GetFunctionTableFailed;
    return @intToPtr(ReturnType, ret);
}

fn associateOverlay() !bool {
    var left_hand_id: c.TrackedDeviceIndex_t = o_system.GetTrackedDeviceIndexForControllerRole.?(
        c.ETrackedControllerRole_TrackedControllerRole_LeftHand,
    );
    if(left_hand_id == 0 or left_hand_id == -1) return false;
    std.log.info("left hand id: {d}", .{left_hand_id});

    var transform = std.mem.zeroes(c.struct_HmdMatrix34_t);
    transform.m[0][0] = 1;
    transform.m[1][1] = 1;
    transform.m[2][2] = 1;

    if(o_overlay.SetOverlayTransformTrackedDeviceRelative.?(ul_handle, left_hand_id, &transform) != 0) return error.SetTransformFailed;

    return true;
}

var o_system: *c.struct_VR_IVRSystem_FnTable = undefined;
var o_overlay: *c.struct_VR_IVROverlay_FnTable = undefined;
var ul_handle: c.VROverlayHandle_t = undefined;

const WIDTH = 256;
const HEIGHT = 256;

pub fn main() !void {
    var has_associated_overlay = false;

    if(c.CNFGSetup("Example App", WIDTH, HEIGHT) != 0) {
        return error.FailedCNFGSetup;
    }
    std.log.info("CNFG Initialized", .{});

    std.log.info("Initializing OpenVR…", .{});
    {
        var err: c.EVRInitError = undefined;
        _ = c.VR_InitInternal(&err, c.EVRApplicationType_VRApplication_Overlay);
        if(err != c.EVRInitError_VRInitError_None) { // != 0 is equivalent
            std.log.err("error code: {d}", .{err});
            return error.FailedOpenVRInit;
        }
    }
    std.log.info("OpenVR Initialized", .{});

    o_overlay = try CNOVRGetOpenVRFunctionTable(*c.VR_IVROverlay_FnTable, c.IVROverlay_Version.?);
    o_system = try CNOVRGetOpenVRFunctionTable(*c.VR_IVRSystem_FnTable, c.IVROverlay_Version.?);

    var overlay_key = "una-time".*;
    var overlay_name = "unatime".*;
    if(o_overlay.CreateOverlay.?(&overlay_key, &overlay_name, &ul_handle) != 0) return error.EvrOverlayError;
    if(o_overlay.SetOverlayWidthInMeters.?(ul_handle, 0.3) != 0) return error.EvrOverlayError;
    if(o_overlay.SetOverlayColor.?(ul_handle, 1.0, 1.0, 1.0) != 0) return error.EvrOverlayError;

    var bounds: c.VRTextureBounds_t = .{
        .uMin = 0,
        .uMax = 1,
        .vMin = 0,
        .vMax = 1,
    };
    if(o_overlay.SetOverlayTextureBounds.?(ul_handle, &bounds) != 0) return error.EvrOverlayError;

    if(o_overlay.ShowOverlay.?(ul_handle) != 0) return error.EvrOverlayError;

    var texture: c.GLuint = undefined;
    c.glGenTextures(1, &texture);
    c.glBindTexture(c.GL_TEXTURE_2D, texture);
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGB, WIDTH, HEIGHT, 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, null);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);

    while(c.CNFGHandleInput() != 0) {
        c.CNFGBGColor = 0x000080ff;

        var w: c_short = undefined;
        var h: c_short = undefined;
        c.CNFGClearFrame();
        c.CNFGGetDimensions(&w, &h);

        _ = c.CNFGColor(0xffffffff); // returns the color you gave it? ??

        c.CNFGPenX = 1;
        c.CNFGPenY = 1;
        c.CNFGDrawText("Hello, World!", 2);

        c.CNFGTackPixel(30, 30); // draw a single pixel

        c.CNFGTackSegment(50, 50, 100, 50); // line x1 y1 x2 y2

        // done drawing
        c.CNFGSwapBuffers();

        if(!has_associated_overlay) {
            has_associated_overlay = try associateOverlay();
        }

        c.glBindTexture(c.GL_TEXTURE_2D, texture);
        c.glCopyTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, 0, 0, WIDTH, HEIGHT, 0);
        var overlay_texture: c.struct_Texture_t = .{
            .eType = c.ETextureType_TextureType_OpenGL,
            .eColorSpace = c.EColorSpace_ColorSpace_Auto,
            .handle = @intToPtr(?*anyopaque, texture),
        };
        if(o_overlay.SetOverlayTexture.?(ul_handle, &overlay_texture) != 0) return error.OverlayError;
    }
}
