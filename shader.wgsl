struct MyUniforms {
    color: vec4f,
    time: f32,
};

@group(0) @binding(0) var<uniform> myUniforms: MyUniforms;

struct VertexInput {
    @location(0) position: vec2f,
    @location(1) color: vec3f,
}

struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) color: vec3f, // Corresponds to the fs_main parameter decorator
}

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    let ratio = 640.0 / 480.0;
    var offset = vec2f(-0.6875, -0.463); // The offset that we want to apply to the position
    offset += 0.3 * vec2f(cos(myUniforms.time), sin(myUniforms.time)); // Move the triangles around a circle

    var out: VertexOutput;

    out.position = vec4f(in.position.x + offset.x, (in.position.y + offset.y) * ratio, 0.0, 1.0);
    out.color = in.color;

    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4f {
    let color = in.color * myUniforms.color.rgb;

    // Fix color space (gamma correction)
    // 2.2 is just an approximation
    let linear_color = pow(color, vec3f(2.2));

    return vec4f(linear_color, 1.0);
}
