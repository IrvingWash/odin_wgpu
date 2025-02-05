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

   output.position = vec4f(input.vertex_position.x, input.vertex_position.y * ratio, 0, 1);
   output.color = input.color;

   return output;
}

@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4f {
    return vec4f(input.color, 1.0);
}
