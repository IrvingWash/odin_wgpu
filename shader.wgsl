@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4f {
    var position = vec2f(0, 0);

    if (vertex_index == 0) {
        position = vec2f(-0.5, -0.5);
    } else if (vertex_index == 1) {
        position = vec2f(0.5, -0.5);
    } else {
        position = vec2f(0, 0.5);
    }

    return vec4f(position, 0, 1);
}

@fragment
fn fs_main() -> @location(0) vec4f {
    return vec4f(0.0, 0.4, 1.0, 1.0);
}
