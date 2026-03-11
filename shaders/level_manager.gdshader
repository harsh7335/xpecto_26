shader_type canvas_item;

uniform vec4 mask_color : source_color = vec4(1.0, 0.0, 1.0, 1.0); 
uniform vec4 water_dark : source_color = vec4(0.0, 0.4, 0.8, 1.0); 
uniform vec4 water_light : source_color = vec4(0.0, 0.65, 0.95, 1.0); 

uniform float speed = 2.0; 
uniform float wave_density = 25.0; 

void fragment() {
    vec4 pixel_color = texture(TEXTURE, UV);

    if (distance(pixel_color.rgb, mask_color.rgb) < 0.1 && pixel_color.a > 0.0) {
        
        // Overlap three different waves moving in different directions
        float wave1 = sin(SCREEN_UV.x * wave_density + TIME * speed);
        float wave2 = cos(SCREEN_UV.y * wave_density + TIME * speed * 0.8); 
        float wave3 = sin((SCREEN_UV.x + SCREEN_UV.y) * wave_density * 0.5 - TIME * speed);
        
        // Multiply them together to create organic "blobs" and ripples
        float combined_wave = wave1 * wave2 * wave3;
        
        // Normalize the wave math so it blends smoothly between the two blues
        combined_wave = combined_wave * 0.5 + 0.5;
        
        vec3 final_water = mix(water_dark.rgb, water_light.rgb, combined_wave);
        
        COLOR = vec4(final_water, pixel_color.a);
        
    } else {
        COLOR = pixel_color;
    }
}