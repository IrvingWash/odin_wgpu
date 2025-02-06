struct MyUniforms {
    color: vec4f,
    time: f32,
};

@group(0) @binding(0) var<uniform> uMyUniforms: MyUniforms;

struct VertexInput {
    @location(0) position: vec3f,
    @location(1) color: vec3f,
};

struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) color: vec3f,
};

@vertex
fn vs_main(input: VertexInput) -> VertexOutput {
	var output: VertexOutput;
	let ratio = 640.0 / 480.0;

	let angle = uMyUniforms.time;

	// Rotate the position around the X axis by "mixing" a bit of Y and Z in the original Y and Z.
	let alpha = cos(angle);
	let beta = sin(angle);
	var position = vec3f(
		input.position.x,
		alpha * input.position.y + beta * input.position.z,
		alpha * input.position.z - beta * input.position.y,
	);

	output.position = vec4f(position.x, position.y * ratio, 0.0, 1.0);
	output.color = input.color;

	return output;
}

@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4f {
    return vec4f(input.color * uMyUniforms.color.rgb, 1.0);
}
