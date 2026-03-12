shader_type canvas_item;

varying vec2 world_pos;

uniform float speed = 3.0;        
uniform float ray_size = 0.05;    

// ---> NEW: Tweak the dust directly from the Inspector! <---
uniform vec4 mote_color : source_color = vec4(1.0, 0.7, 0.1, 1.0);
uniform float mote_size : hint_range(0.01, 0.1) = 0.04;
uniform float mote_density : hint_range(0.1, 0.9) = 0.7;
uniform float mote_intensity : hint_range(1.0, 10.0) = 4.0;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // The Light Waves
    float ray = sin(world_pos.x * ray_size + world_pos.y * ray_size - TIME * speed);
    ray = smoothstep(-1.0, 1.0, ray);
    
    COLOR = tex_color * COLOR;
    COLOR.a *= 0.6 + (ray * 0.4); 
    COLOR.rgb += vec3(ray * 0.2); 
    
    // The Dust Motes (Using your new sliders!)
    vec2 mote_pos = world_pos * mote_size + vec2(TIME * 0.8, TIME * -1.5);
    float mote_noise = sin(mote_pos.x) * cos(mote_pos.y) * sin(mote_pos.x * 1.5 + TIME) * cos(mote_pos.y * 1.2 - TIME);
    
    float motes = smoothstep(mote_density, 1.0, mote_noise);
    
    // We use a very pale, bright yellow so it pops against the dark yellow background
    vec3 base_mote_color = vec3(1.0, 0.9, 0.4);
    
    vec3 glowing_dust = mote_color.rgb * mote_intensity;
    
    // 2. MIX paints your dust perfectly over the beam instead of adding them together!
    COLOR.rgb = mix(COLOR.rgb, glowing_dust, motes);
}