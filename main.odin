package main

import "core:fmt"
import "vendor:wgpu"

main :: proc() {
	instance_descriptor := wgpu.InstanceDescriptor{}

	instance := wgpu.CreateInstance(&instance_descriptor)
	if instance == nil {
		panic("Failed to craete WGPU Instance")
	}
	defer wgpu.InstanceRelease(instance)
}

