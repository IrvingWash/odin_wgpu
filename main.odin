package main

import "base:runtime"
import "core:fmt"
import "vendor:glfw"
import "vendor:wgpu"
import "vendor:wgpu/glfwglue"

main :: proc() {
	init()

	run()

	destroy()
}

WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600

State :: struct {
	window:  glfw.WindowHandle,
	surface: wgpu.Surface,
	device:  wgpu.Device,
	queue:   wgpu.Queue,
}

state := State{}

init :: proc() {
	// Window
	if !glfw.Init() {
		panic("Failed to initialize GLWF")
	}
	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
	glfw.WindowHint(glfw.RESIZABLE, false)
	state.window = glfw.CreateWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "WGPU", nil, nil)

	// Instance
	instance := wgpu.CreateInstance()
	defer wgpu.InstanceRelease(instance)

	// Surface
	state.surface = glfwglue.GetSurface(instance, state.window)

	// Adapter
	adapter := request_adapter(instance)
	defer wgpu.AdapterRelease(adapter)

	// Device
	state.device = request_device(adapter)

	// Queue
	state.queue = wgpu.DeviceGetQueue(state.device)

	// Surface configuration
	wgpu.SurfaceConfigure(
		state.surface,
		&wgpu.SurfaceConfiguration {
			device = state.device,
			usage = {.RenderAttachment},
			width = WINDOW_WIDTH,
			height = WINDOW_HEIGHT,
			format = .BGRA8Unorm,
			alphaMode = .Auto,
			presentMode = .Fifo,
		},
	)
}

run :: proc() {
	for !glfw.WindowShouldClose(state.window) {
		glfw.PollEvents()

		texture_view := get_next_texture_view()

		command_encoder := wgpu.DeviceCreateCommandEncoder(state.device)

		render_pass_encoder := wgpu.CommandEncoderBeginRenderPass(
			command_encoder,
			&wgpu.RenderPassDescriptor {
				colorAttachmentCount = 1,
				colorAttachments = &wgpu.RenderPassColorAttachment {
					view = texture_view,
					loadOp = .Clear,
					storeOp = .Store,
					clearValue = wgpu.Color{0.7, 0, 0, 1},
				},
			},
		)

		wgpu.RenderPassEncoderEnd(render_pass_encoder)
		wgpu.RenderPassEncoderRelease(render_pass_encoder)

		command_buffer := wgpu.CommandEncoderFinish(command_encoder)

		wgpu.CommandEncoderRelease(command_encoder)

		wgpu.QueueSubmit(state.queue, {command_buffer})

		wgpu.CommandBufferRelease(command_buffer)

		wgpu.TextureViewRelease(texture_view)

		wgpu.SurfacePresent(state.surface)
	}
}

destroy :: proc() {
	wgpu.QueueRelease(state.queue)
	wgpu.DeviceRelease(state.device)
	wgpu.SurfaceUnconfigure(state.surface)
	wgpu.SurfaceRelease(state.surface)
	glfw.DestroyWindow(state.window)
	glfw.Terminate()
}

get_next_texture_view :: proc() -> wgpu.TextureView {
	surface_texture := wgpu.SurfaceGetCurrentTexture(state.surface)

	texture_view := wgpu.TextureCreateView(
		surface_texture.texture,
		&wgpu.TextureViewDescriptor {
			format          = wgpu.TextureGetFormat(surface_texture.texture),
			// What are these?
			arrayLayerCount = 1,
			mipLevelCount   = 1,
			dimension       = ._2D,
			aspect          = .All,
		},
	)

	// Should not release manually
	// wgpu.TextureRelease(surface_texture.texture)

	return texture_view
}

request_device :: proc(adapter: wgpu.Adapter) -> wgpu.Device {
	Out :: struct {
		ctx:    runtime.Context,
		device: wgpu.Device,
	}

	out := Out {
		ctx = context,
	}

	wgpu.AdapterRequestDevice(
		adapter,
		&wgpu.DeviceDescriptor{},
		proc "c" (
			status: wgpu.RequestDeviceStatus,
			device: wgpu.Device,
			message: cstring,
			userdata: rawptr,
		) {
			data := cast(^Out)userdata

			context = data.ctx

			if status != .Success {
				fmt.panicf("Failed to request WGPU Device: %s", message)
			}

			data.device = device
		},
		&out,
	)

	return out.device
}

request_adapter :: proc(instance: wgpu.Instance) -> wgpu.Adapter {
	Out :: struct {
		ctx:     runtime.Context,
		adapter: wgpu.Adapter,
	}

	out := Out {
		ctx = context,
	}

	wgpu.InstanceRequestAdapter(
		instance,
		&wgpu.RequestAdapterOptions{compatibleSurface = state.surface},
		proc "c" (
			status: wgpu.RequestAdapterStatus,
			adapter: wgpu.Adapter,
			message: cstring,
			userdata: rawptr,
		) {
			data := cast(^Out)userdata

			context = data.ctx

			if status != .Success {
				fmt.panicf("Failed to request WGPU Adapter: %s", message)
			}

			data.adapter = adapter
		},
		&out,
	)

	return out.adapter
}

