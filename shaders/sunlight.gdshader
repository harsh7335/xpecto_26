shader_type canvas_item;
varying vec2 world_pos;

uniform float speed = 3.0;        // How fast the light waves travel
uniform float ray_size = 0.05;    // How wide the waves are

void vertex() {
    // 1. Grab the exact physical coordinate of the tile in the game world
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
    // 2. Get the base texture and your script's neon yellow modulation
    vec4 tex_color = texture(TEXTURE, UV);
    
    // 3. Create diagonal sweeping waves of light using sine math and time!
    float ray = sin(world_pos.x * ray_size + world_pos.y * ray_size - TIME * speed);
    
    // 4. Soften the math wave into a smooth glow (values between 0.0 and 1.0)
    ray = smoothstep(-1.0, 1.0, ray);
    
    // 5. Apply the base color
    COLOR = tex_color * COLOR;
    
    // 6. The Magic! Pulse the transparency and brightness using our wave
    COLOR.a *= 0.6 + (ray * 0.4); // Makes the opacity shimmer
    COLOR.rgb += vec3(ray * 0.2); // Adds a bright white-hot core to the wave
}