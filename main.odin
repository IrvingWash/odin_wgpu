package main

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:strings"
import "vendor:glfw"
import "vendor:wgpu"
import "vendor:wgpu/glfwglue"

main :: proc() {
	// =============================
	// Memory tracking
	// =============================
	when ODIN_DEBUG {
		context.logger = log.create_console_logger(lowest = log.Level.Debug)
		defer log.destroy_console_logger(context.logger)

		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}

			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}

			mem.tracking_allocator_destroy(&track)
		}
	}

	// =============================
	// The actual code
	// =============================
	app := Application{}

	app_init(&app)

	for app_is_running(app) {
		app_main_loop(&app)
	}

	app_terminate(app)
}

ctx: runtime.Context

Application :: struct {
	window:          glfw.WindowHandle,
	device:          wgpu.Device,
	queue:           wgpu.Queue,
	surface:         wgpu.Surface,
	surface_format:  wgpu.TextureFormat,
	render_pipeline: wgpu.RenderPipeline,
	vertex_buffer:   wgpu.Buffer, // Buffer containing vertex data
	vertex_count:    u32, // Count of vertices to use in the draw call
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
	app.surface_format = surface_capabilities.formats[0]
	surface_config := wgpu.SurfaceConfiguration {
		width       = 640, // Same as window width for GLFW
		height      = 480, // Same as window height for GLFW
		format      = app.surface_format,
		usage       = wgpu.TextureUsageFlags{.RenderAttachment}, // The surface/texture will be used for rendering
		device      = app.device,
		presentMode = .Fifo,
		alphaMode   = .Auto,
	}
	wgpu.SurfaceConfigure(app.surface, &surface_config)

	// Initialize the render pipeline
	initialize_render_pipeline(app)

	// Pass vertex data to GPU
	init_buffers(app)
}

app_terminate :: proc(app: Application) {
	wgpu.BufferRelease(app.vertex_buffer)
	wgpu.RenderPipelineRelease(app.render_pipeline)
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
	wgpu.RenderPassEncoderSetPipeline(render_pass_encoder, app.render_pipeline)

	// Set vertex buffer to draw it
	wgpu.RenderPassEncoderSetVertexBuffer(
		render_pass_encoder,
		slot = 0,
		buffer = app.vertex_buffer,
		offset = 0,
		size = wgpu.BufferGetSize(app.vertex_buffer),
	)

	wgpu.RenderPassEncoderDraw(
		render_pass_encoder,
		app.vertex_count,
		instanceCount = 1,
		firstVertex = 0,
		firstInstance = 0,
	)
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

init_buffers :: proc(app: ^Application) {
	// Coordinates of vertices
	// odinfmt: disable
	vertex_data := [?]f32 {
		// Left triangle
		-0.5, -0.5,
		+0.5, -0.5,
		+0.0, +0.5,

		// Center triangle
		-0.55, -0.5,
		-0.05, +0.5,
		-0.55, +0.5,

		// Right triangle
		+0.05, +0.5,
		+0.55, -0.5,
		+0.55, +0.5,
	}
	// odinfmt: enable


	app.vertex_count = len(vertex_data) / 2

	// Create the buffer and assign the vertex data into it
	buffer_descriptor := wgpu.BufferDescriptor {
		size  = len(vertex_data) * size_of(f32),
		usage = {.CopyDst, .Vertex},
	}
	app.vertex_buffer = wgpu.DeviceCreateBuffer(app.device, &buffer_descriptor)

	wgpu.QueueWriteBuffer(
		app.queue,
		app.vertex_buffer,
		bufferOffset = 0,
		data = &vertex_data,
		size = auto_cast buffer_descriptor.size,
	)
}

app_is_running :: proc(app: Application) -> bool {
	return !glfw.WindowShouldClose(app.window)
}

initialize_render_pipeline :: proc(app: ^Application) {
	shader_code := load_shader_code()
	// defer delete(shader_code)
	raw_shader_code := strings.clone_to_cstring(shader_code)
	// defer delete(raw_shader_code)
	shader_module_descriptor := wgpu.ShaderModuleDescriptor {
		label       = "My shader module",
		nextInChain = &wgpu.ShaderModuleWGSLDescriptor {
			sType = .ShaderModuleWGSLDescriptor,
			code = raw_shader_code,
		},
	}
	shader_module := wgpu.DeviceCreateShaderModule(app.device, &shader_module_descriptor)
	defer wgpu.ShaderModuleRelease(shader_module)

	render_pipeline_descriptor := wgpu.RenderPipelineDescriptor {
		vertex = wgpu.VertexState {
			bufferCount = 1, // We have only one buffer
			buffers     = &wgpu.VertexBufferLayout {
				attributeCount = 1, // We pass only position data -- one attribute
				attributes     = &wgpu.VertexAttribute {
					shaderLocation = 0, // @location(0)
					format         = .Float32x2, // We have x, y coordinates, both are f32
					offset         = 0, // Only positions in the array, so no need for offset
				},
				arrayStride    = 2 * size_of(f32), // each vertex contains two values
				stepMode       = .Vertex, // Values correspond to different vertices
			},
			module      = shader_module,
			entryPoint  = "vs_main",
		},
		primitive = wgpu.PrimitiveState {
			// Each sequence of 3 vertices will be considered as a triangle
			topology         = .TriangleList,
			// How to connect vertices, `Undefined` == sequential connection
			stripIndexFormat = .Undefined,
			// A "face" of the triangle is the side where the vertices are connected Counter ClockWise
			frontFace        = .CCW,
			// Cull (hide) faces pointing to the opposite direction.
			cullMode         = .Back,
		},
		fragment = &wgpu.FragmentState {
			module      = shader_module,
			entryPoint  = "fs_main",
			// We have one target because our render pass has only one color attachement
			targetCount = 1,
			targets     = &wgpu.ColorTargetState {
				format = app.surface_format,
				blend = &wgpu.BlendState {
					color = wgpu.BlendComponent {
						srcFactor = .SrcAlpha,
						dstFactor = .OneMinusSrcAlpha,
						operation = .Add,
					},
					alpha = wgpu.BlendComponent {
						srcFactor = .Zero,
						dstFactor = .One,
						operation = .Add,
					},
				},
				writeMask = wgpu.ColorWriteMaskFlags{.Red, .Green, .Blue, .Alpha},
			},
		},
		// Another optimization config. Hides overlapping pixels based on the depth.
		// Not using for now
		depthStencil = nil,
		multisample = wgpu.MultisampleState {
			// Samples per pixel
			count = 1,
		},
		// Memory layout for input/output resources. We don't need any for now
		layout = nil,
	}

	app.render_pipeline = wgpu.DeviceCreateRenderPipeline(app.device, &render_pipeline_descriptor)
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

load_shader_code :: proc() -> string {
	path := "shader.wgsl"

	bytes, ok := os.read_entire_file(path)
	if !ok {
		fmt.panicf("Failed to read file: %s", path)
	}
	defer delete(bytes)

	return strings.clone_from_bytes(bytes)
}
