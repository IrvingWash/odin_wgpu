struct MyUniforms {
    color: vec4f,
    time: f32,
};

@group(0) @binding(0) var<uniform> uMyUniforms: MyUniforms;

struct VertexInput {
    @location(0) vertex_position: vec3f,
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
    var offset = vec3f(0);
    offset += 0.3 * vec3f(cos(uMyUniforms.time), sin(uMyUniforms.time), 1);

    let position_with_offset = input.vertex_position + offset;

     output.position = vec4f(position_with_offset.x, position_with_offset.y * ratio, 0, 1);
     output.color = input.color;

     return output;
}

@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4f {
    return vec4f(input.color * uMyUniforms.color.rgb, 1.0);
}
