package main

import "base:runtime"
import "core:fmt"
import "vendor:wgpu"

ctx: runtime.Context

main :: proc() {
	// Get an instance to begin working with WGPU
	instance_descriptor := wgpu.InstanceDescriptor{}
	instance := wgpu.CreateInstance(&instance_descriptor)
	if instance == nil {
		panic("Failed to craete WGPU Instance")
	}
	defer wgpu.InstanceRelease(instance)

	// Get an adapter - the representation of the hardware GPU
	adapter := request_adapter_sync(instance, &{})
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
	device := request_device_sync(adapter, &device_descriptor)
	defer wgpu.DeviceRelease(device)
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

