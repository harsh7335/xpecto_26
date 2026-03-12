shader_type canvas_item;

uniform float speed = 3.0;        
uniform float float_height = 4.0; 


void vertex() {
    // 1. Group the pixels into 32x32 grid chunks
    vec2 grid_pos = floor(VERTEX / 32.0);
    
    // 2. Create the wavy offset
    float offset = (grid_pos.x + grid_pos.y) * 0.5;
    
    // 3. The gentle idle bobbing
    VERTEX.y += sin((TIME * speed) + offset) * float_height;
	
	// ---> NEW: The Hover Levitation! <---
	// If this specific chunk is the one the mouse is touching, move it UP!

}