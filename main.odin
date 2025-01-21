package main

import "base:runtime"
import "core:fmt"
import "vendor:glfw"
import "vendor:wgpu"
import "vendor:wgpu/glfwglue"

main :: proc() {
	app := Application{}

	app_init(&app)

	for app_is_running(app) {
		app_main_loop(&app)
	}

	app_terminate(app)
}

ctx: runtime.Context

Application :: struct {
	window:  glfw.WindowHandle,
	device:  wgpu.Device,
	queue:   wgpu.Queue,
	surface: wgpu.Surface,
}

app_init :: proc(app: ^Application) {
	// Init GLFW
	if !glfw.Init() {
		panic("Failed to initialize GLFW")
	}
	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
	glfw.WindowHint(glfw.RESIZABLE, false)
	app.window = glfw.CreateWindow(640, 480, "Learn WGPU", nil, nil)
	if app.window == nil {
		panic("Failed to create window")
	}

	// Get an instance to begin working with WGPU
	instance_descriptor := wgpu.InstanceDescriptor{}
	instance := wgpu.CreateInstance(&instance_descriptor)
	if instance == nil {
		panic("Failed to craete WGPU Instance")
	}
	defer wgpu.InstanceRelease(instance)

	// Get the surface to draw on
	app.surface = glfwglue.GetSurface(instance, app.window)

	// Get an adapter - the representation of the hardware GPU
	adapter_options := wgpu.RequestAdapterOptions {
		compatibleSurface = app.surface,
	}
	adapter := request_adapter_sync(instance, &adapter_options)
	defer wgpu.AdapterRelease(adapter)

	// The device is the handle to the GPU API
	ctx = context
	device_descriptor := wgpu.DeviceDescriptor {
		label = "My device",
		defaultQueue = wgpu.QueueDescriptor{label = "The default queue"},
		deviceLostCallback = proc "c" (
			reason: wgpu.DeviceLostReason,
			message: cstring,
			user_data: rawptr,
		) {
			context = ctx

			fmt.printfln("Device lost: %s, %s", reason, message)
		},
		uncapturedErrorCallbackInfo = wgpu.UncapturedErrorCallbackInfo {
			callback = proc "c" (type: wgpu.ErrorType, message: cstring, user_data: rawptr) {
				context = ctx

				fmt.printfln("Uncaptured device error: %s, %s", type, message)
			},
		},
	}
	app.device = request_device_sync(adapter, &device_descriptor)

	// Command Queue is a queue through which the CPU sends commands to the GPU
	// The queue should be gotten only once
	app.queue = wgpu.DeviceGetQueue(app.device)

	// Configure the surface to draw onto
	surface_capabilities := wgpu.SurfaceGetCapabilities(app.surface, adapter)
	surface_config := wgpu.SurfaceConfiguration {
		width       = 640, // Same as window width for GLFW
		height      = 480, // Same as window height for GLFW
		format      = surface_capabilities.formats[0],
		usage       = wgpu.TextureUsageFlags{.RenderAttachment}, // The surface/texture will be used for rendering
		device      = app.device,
		presentMode = .Fifo,
		alphaMode   = .Auto,
	}
	wgpu.SurfaceConfigure(app.surface, &surface_config)
}

app_terminate :: proc(app: Application) {
	wgpu.SurfaceUnconfigure(app.surface)
	wgpu.SurfaceRelease(app.surface)
	glfw.DestroyWindow(app.window)
	glfw.Terminate()
	wgpu.QueueRelease(app.queue)
	wgpu.DeviceRelease(app.device)
}

app_main_loop :: proc(app: ^Application) {
	glfw.PollEvents()

	// Get the next view in the swap chain to draw on
	texture_view, texture_view_ok := get_next_texture_view(app^).?
	if !texture_view_ok {
		return
	}

	encoder_descriptor := wgpu.CommandEncoderDescriptor {
		label = "My command encoder",
	}
	encoder := wgpu.DeviceCreateCommandEncoder(app.device, &encoder_descriptor)

	render_pass_descriptor := wgpu.RenderPassDescriptor {
		colorAttachmentCount = 1,
		colorAttachments     = &wgpu.RenderPassColorAttachment {
			view = texture_view,
			loadOp = .Clear,
			storeOp = .Store,
			clearValue = wgpu.Color{0.9, 0.1, 0.2, 1.0},
			depthSlice = 0,
		},
	}
	render_pass_encoder := wgpu.CommandEncoderBeginRenderPass(encoder, &render_pass_descriptor)
	wgpu.RenderPassEncoderEnd(render_pass_encoder)
	wgpu.RenderPassEncoderRelease(render_pass_encoder)

	cmd_buffer_descriptor := wgpu.CommandBufferDescriptor {
		label = "My command buffer",
	}
	cmd_buffer := wgpu.CommandEncoderFinish(encoder, &cmd_buffer_descriptor)
	wgpu.CommandEncoderRelease(encoder)

	wgpu.QueueSubmit(app.queue, {cmd_buffer})
	wgpu.CommandBufferRelease(cmd_buffer)

	wgpu.TextureViewRelease(texture_view)

	wgpu.SurfacePresent(app.surface)
}

app_is_running :: proc(app: Application) -> bool {
	return !glfw.WindowShouldClose(app.window)
}

get_next_texture_view :: proc(app: Application) -> Maybe(wgpu.TextureView) {
	surface_texture := wgpu.SurfaceGetCurrentTexture(app.surface)
	if surface_texture.status != .Success {
		return nil
	}

	texture_view_descriptor := wgpu.TextureViewDescriptor {
		label           = "My surface texture view",
		format          = wgpu.TextureGetFormat(surface_texture.texture),
		dimension       = ._2D,
		mipLevelCount   = 1,
		arrayLayerCount = 1,
		aspect          = .All,
	}

	texture_view := wgpu.TextureCreateView(surface_texture.texture, &texture_view_descriptor)

	return texture_view
}

request_adapter_sync :: proc(
	instance: wgpu.Instance,
	options: ^wgpu.RequestAdapterOptions,
) -> wgpu.Adapter {
	User_Data :: struct {
		adapter:       wgpu.Adapter,
		request_ended: bool,
	}

	user_data: User_Data

	ctx = context

	on_adapter_request_ended :: proc "c" (
		status: wgpu.RequestAdapterStatus,
		adapter: wgpu.Adapter,
		message: cstring,
		p_user_data: rawptr,
	) {
		context = ctx

		user_data := cast(^User_Data)p_user_data

		if status == .Success {
			user_data.adapter = adapter
		} else {
			panic("Could not get WGPU adapter")
		}

		user_data.request_ended = true
	}

	wgpu.InstanceRequestAdapter(instance, options, on_adapter_request_ended, &user_data)

	return user_data.adapter
}

request_device_sync :: proc(
	adapter: wgpu.Adapter,
	descriptor: ^wgpu.DeviceDescriptor,
) -> wgpu.Device {
	User_Data :: struct {
		device:        wgpu.Device,
		request_ended: bool,
	}

	user_data: User_Data

	ctx = context

	on_device_request_ended :: proc "c" (
		status: wgpu.RequestDeviceStatus,
		device: wgpu.Device,
		message: cstring,
		p_user_data: rawptr,
	) {
		context = ctx

		user_data := cast(^User_Data)p_user_data

		if status == .Success {
			user_data.device = device
		} else {
			panic("Could not get WGPU device")
		}

		user_data.request_ended = true
	}

	wgpu.AdapterRequestDevice(adapter, descriptor, on_device_request_ended, &user_data)

	return user_data.device
}

