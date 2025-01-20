package main

import "base:runtime"
import "core:fmt"
import "vendor:glfw"
import "vendor:wgpu"
import "vendor:wgpu/glfwglue"

main :: proc() {
	app := Application{}

	app_init(&app)
	defer app_terminate(app)

	for app_is_running(app) {
		app_main_loop(&app)
	}
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

	// Command Encoder encodes the commands that should be passed to the queue
	// Should be recreated every time
	encoder_descriptor := wgpu.CommandEncoderDescriptor {
		label = "My command encoder",
	}
	encoder := wgpu.DeviceCreateCommandEncoder(app.device, &encoder_descriptor)
	wgpu.CommandEncoderInsertDebugMarker(encoder, "Do one thing")
	wgpu.CommandEncoderInsertDebugMarker(encoder, "Do another thing")

	// Command buffer is the result of all the commands passed into the encoder
	command_buffer_descriptor := wgpu.CommandBufferDescriptor {
		label = "My command buffer",
	}
	command := wgpu.CommandEncoderFinish(encoder, &command_buffer_descriptor)
	wgpu.CommandEncoderRelease(encoder)

	wgpu.QueueSubmit(app.queue, {command})
	wgpu.CommandBufferRelease(command)
}

app_terminate :: proc(app: Application) {
	wgpu.SurfaceRelease(app.surface)
	glfw.DestroyWindow(app.window)
	glfw.Terminate()
	wgpu.QueueRelease(app.queue)
	wgpu.DeviceRelease(app.device)
}

app_main_loop :: proc(app: ^Application) {
	glfw.PollEvents()
}

app_is_running :: proc(app: Application) -> bool {
	return !glfw.WindowShouldClose(app.window)
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

