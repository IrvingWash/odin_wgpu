@group(0) @binding(0) var<uniform> uTime: f32;

struct VertexInput {
    @location(0) vertex_position: vec2f,
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
    var offset = vec2f(-0.6875, -0.463);
    offset += 0.3 * vec2f(cos(uTime), sin(uTime));

    let position_with_offset = input.vertex_position + offset;

     output.position = vec4f(position_with_offset.x, position_with_offset.y * ratio, 0, 1);
     output.color = input.color;

     return output;
}

@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4f {
    return vec4f(input.color, 1.0);
}
