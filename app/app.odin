package app

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"
import "vendor:glfw"
import "vendor:wgpu"
import "vendor:wgpu/glfwglue"

@(private = "file")
WINDOW_WIDTH :: 640
@(private = "file")
WINDOW_HEIGHT :: 480

@(private = "file")
State :: struct {
	window:            glfw.WindowHandle,
	surface:           wgpu.Surface,
	device:            wgpu.Device,
	queue:             wgpu.Queue,
	render_pipeline:   wgpu.RenderPipeline,
	texture_format:    wgpu.TextureFormat,
	vertex_buffer:     wgpu.Buffer,
	vertex_count:      uint,
	index_buffer:      wgpu.Buffer,
	index_count:       uint,
	uniform_buffer:    wgpu.Buffer,
	bind_group_layout: wgpu.BindGroupLayout,
	bind_group:        wgpu.BindGroup,
}

@(private = "file")
state := State{}

@(private = "file")
MyUniforms :: struct {
	color: [4]f32,
	time:  f32,
	pad:   [3]f32,
}

init :: proc() {
	// FPS manager
	fps_manager_init(60)

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
	state.texture_format = .BGRA8Unorm

	wgpu.SurfaceConfigure(
		state.surface,
		&wgpu.SurfaceConfiguration {
			device = state.device,
			usage = {.RenderAttachment},
			width = WINDOW_WIDTH,
			height = WINDOW_HEIGHT,
			format = state.texture_format,
			alphaMode = .Auto,
			presentMode = .Fifo,
		},
	)

	// Render pipeline
	state.render_pipeline, state.bind_group_layout = create_render_pipeline()

	// Vertex position buffer
	state.vertex_buffer, state.vertex_count, state.index_buffer, state.index_count, state.uniform_buffer =
		create_buffers()

	// Bind groups
	state.bind_group = create_bind_groups()
}

run :: proc() {
	for !glfw.WindowShouldClose(state.window) {
		cap_fps()

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
					clearValue = wgpu.Color{0.05, 0.05, 0.05, 1},
				},
			},
		)

		wgpu.RenderPassEncoderSetPipeline(render_pass_encoder, state.render_pipeline)
		wgpu.RenderPassEncoderSetVertexBuffer(
			render_pass_encoder,
			0,
			state.vertex_buffer,
			0,
			wgpu.BufferGetSize(state.vertex_buffer),
		)
		wgpu.RenderPassEncoderSetIndexBuffer(
			render_pass_encoder,
			state.index_buffer,
			.Uint16,
			0,
			wgpu.BufferGetSize(state.index_buffer),
		)
		wgpu.QueueWriteBuffer(
			state.queue,
			state.uniform_buffer,
			0,
			&MyUniforms{time = f32(glfw.GetTime()), color = {0, 1, 0.4, 1}},
			size_of(MyUniforms),
		)
		wgpu.RenderPassEncoderSetBindGroup(render_pass_encoder, 0, state.bind_group)
		wgpu.RenderPassEncoderDrawIndexed(render_pass_encoder, u32(state.index_count), 1, 0, 0, 0)
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
	wgpu.BindGroupRelease(state.bind_group)
	wgpu.BindGroupLayoutRelease(state.bind_group_layout)
	wgpu.BufferRelease(state.uniform_buffer)
	wgpu.BufferRelease(state.index_buffer)
	wgpu.BufferRelease(state.vertex_buffer)
	wgpu.RenderPipelineRelease(state.render_pipeline)
	wgpu.QueueRelease(state.queue)
	wgpu.DeviceRelease(state.device)
	wgpu.SurfaceUnconfigure(state.surface)
	wgpu.SurfaceRelease(state.surface)
	glfw.DestroyWindow(state.window)
	glfw.Terminate()
}

@(private = "file")
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

@(private = "file")
create_render_pipeline :: proc() -> (wgpu.RenderPipeline, wgpu.BindGroupLayout) {
	shader_source_bytes, _ := os.read_entire_file("./app/shader.wgsl")
	shader_source := strings.clone_from_bytes(shader_source_bytes)
	delete(shader_source_bytes)
	shader_source_raw := strings.clone_to_cstring(shader_source)
	delete(shader_source)

	shader_module := wgpu.DeviceCreateShaderModule(
		state.device,
		&wgpu.ShaderModuleDescriptor {
			nextInChain = &wgpu.ShaderModuleWGSLDescriptor {
				sType = .ShaderModuleWGSLDescriptor,
				code = shader_source_raw,
			},
		},
	)

	delete(shader_source_raw)

	vertex_attributes := [?]wgpu.VertexAttribute {
		wgpu.VertexAttribute{format = .Float32x2, offset = 0, shaderLocation = 0},
		wgpu.VertexAttribute{format = .Float32x3, offset = 2 * size_of(f32), shaderLocation = 1},
	}

	bind_group_layout := wgpu.DeviceCreateBindGroupLayout(
		state.device,
		&wgpu.BindGroupLayoutDescriptor {
			entryCount = 1,
			entries = &wgpu.BindGroupLayoutEntry {
				binding = 0,
				visibility = {.Vertex, .Fragment},
				buffer = wgpu.BufferBindingLayout {
					type = .Uniform,
					minBindingSize = size_of(MyUniforms),
				},
			},
		},
	)

	pipeline_layout := wgpu.DeviceCreatePipelineLayout(
		state.device,
		&wgpu.PipelineLayoutDescriptor {
			bindGroupLayoutCount = 1,
			bindGroupLayouts = &bind_group_layout,
		},
	)

	render_pipeline := wgpu.DeviceCreateRenderPipeline(
		state.device,
		&wgpu.RenderPipelineDescriptor {
			vertex = wgpu.VertexState {
				entryPoint = "vs_main",
				module = shader_module,
				bufferCount = 1,
				buffers = &wgpu.VertexBufferLayout {
					arrayStride = u64(5 * size_of(f32)),
					stepMode = .Vertex,
					attributeCount = len(vertex_attributes),
					attributes = raw_data(vertex_attributes[:]),
				},
			},
			primitive = wgpu.PrimitiveState {
				topology         = .TriangleList,
				stripIndexFormat = .Undefined, // What is this?
				frontFace        = .CCW,
				cullMode         = .Back,
			},
			fragment = &wgpu.FragmentState {
				entryPoint = "fs_main",
				module = shader_module,
				targetCount = 1,
				targets = &wgpu.ColorTargetState {
					format = state.texture_format,
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
					writeMask = wgpu.ColorWriteMaskFlags_All,
				},
			},
			multisample = wgpu.MultisampleState {
				count = 1,
				mask = ~u32(0),
				alphaToCoverageEnabled = false,
			},
			layout = pipeline_layout,
		},
	)

	wgpu.PipelineLayoutRelease(pipeline_layout)
	wgpu.ShaderModuleRelease(shader_module)

	return render_pipeline, bind_group_layout
}

@(private = "file")
create_bind_groups :: proc() -> wgpu.BindGroup {
	return wgpu.DeviceCreateBindGroup(
		state.device,
		&wgpu.BindGroupDescriptor {
			entryCount = 1,
			entries = &wgpu.BindGroupEntry {
				binding = 0,
				buffer = state.uniform_buffer,
				offset = 0,
				size = wgpu.BufferGetSize(state.uniform_buffer),
			},
			layout = state.bind_group_layout,
		},
	)
}

@(private = "file")
create_buffers :: proc() -> (wgpu.Buffer, uint, wgpu.Buffer, uint, wgpu.Buffer) {
	geometry := load_geometry("./app/geometry.txt")
	defer destroy_geometry(geometry)

	vertex_buffer := wgpu.DeviceCreateBuffer(
		state.device,
		&wgpu.BufferDescriptor {
			size = u64(slice.size(geometry.vertices[:])),
			usage = {.CopyDst, .Vertex},
		},
	)
	wgpu.QueueWriteBuffer(
		state.queue,
		vertex_buffer,
		0,
		raw_data(geometry.vertices),
		uint(wgpu.BufferGetSize(vertex_buffer)),
	)

	index_buffer := wgpu.DeviceCreateBuffer(
		state.device,
		&wgpu.BufferDescriptor {
			size = u64(ceil_to_multiple(slice.size(geometry.indices[:]), 4)),
			usage = {.CopyDst, .Index},
		},
	)
	wgpu.QueueWriteBuffer(
		state.queue,
		index_buffer,
		0,
		raw_data(geometry.indices),
		uint(wgpu.BufferGetSize(index_buffer)),
	)

	uniform_buffer := wgpu.DeviceCreateBuffer(
		state.device,
		&wgpu.BufferDescriptor{size = size_of(MyUniforms), usage = {.CopyDst, .Uniform}},
	)
	wgpu.QueueWriteBuffer(
		state.queue,
		uniform_buffer,
		0,
		&MyUniforms{time = 1, color = {0, 1, 0.4, 1}},
		size_of(MyUniforms),
	)

	return vertex_buffer,
		len(geometry.vertices) / 5,
		index_buffer,
		len(geometry.indices),
		uniform_buffer
}

@(private = "file")
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

@(private = "file")
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

