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

const pi = 3.14159265359;

@vertex
fn vs_main(input: VertexInput) -> VertexOutput {
        var output: VertexOutput;

        let ratio = 640.0 / 480.0;
        var offset = vec2f(0.0);

        // Scale the object
        let ObjectScale = transpose(mat4x4f(
            0.3,  0.0, 0.0, 0.0,
            0.0,  0.3, 0.0, 0.0,
            0.0,  0.0, 0.3, 0.0,
            0.0,  0.0, 0.0, 1.0,
        ));

        // Translate the object
        let ObjectTranslation = transpose(mat4x4f(
            1.0,  0.0, 0.0, 0.5,
            0.0,  1.0, 0.0, 0.0,
            0.0,  0.0, 1.0, 0.0,
            0.0,  0.0, 0.0, 1.0,
        ));

        // Rotate the model in the XY plane
        let angle1 = uMyUniforms.time;
        let c1 = cos(angle1);
        let s1 = sin(angle1);
        let ObjectRotation = transpose(mat4x4f(
             c1,  s1, 0.0, 0.0,
            -s1,  c1, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            0.0,  0.0, 0.0, 1.0,
        ));

        // Tilt the view point in the YZ plane
        // by three 8th of turn (1 turn = 2 pi)
        let angle2 = 3.0 * pi / 4.0;
        let c2 = cos(angle2);
        let s2 = sin(angle2);
        let ViewPointRotation = transpose(mat4x4f(
            1.0, 0.0, 0.0, 0.0,
            0.0,  c2,  s2, 0.0,
            0.0, -s2,  c2, 0.0,
            0.0,  0.0, 0.0, 1.0,
        ));

        // Compose and apply rotations
        let homogeneous_position = vec4f(input.position, 1.0);
        let position = (ViewPointRotation * ObjectRotation * ObjectTranslation * ObjectScale * homogeneous_position).xyz;

        output.position = vec4<f32>(position.x, position.y * ratio, position.z * 0.5 + 0.5, 1.0);

        output.color = input.color;
        return output;
}

@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4f {
    return vec4f(input.color * uMyUniforms.color.rgb, 1.0);
}
