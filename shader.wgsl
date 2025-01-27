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
    let offset = vec2f(-0.6875, -0.463); // The offset that we want to apply to the position

    var out: VertexOutput;

    out.position = vec4f(in.position.x + offset.x, (in.position.y + offset.y) * ratio, 0.0, 1.0);
    out.color = in.color;

    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4f {
    // Fix color space (gamma correction)
    // 2.2 is just an approximation
    let linear_color = pow(in.color, vec3f(2.2));

    return vec4f(linear_color, 1.0);
}
