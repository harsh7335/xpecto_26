shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Defaults to pure white
uniform float outline_width : hint_range(0.0, 5.0) = 1.0;

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    vec2 ps = TEXTURE_PIXEL_SIZE;
    float a;
    float maxa = col.a;
    float mina = col.a;

    // Check pixels Up, Down, Left, and Right
    a = texture(TEXTURE, UV + vec2(0.0, -outline_width) * ps).a;
    maxa = max(a, maxa);
    mina = min(a, mina);

    a = texture(TEXTURE, UV + vec2(0.0, outline_width) * ps).a;
    maxa = max(a, maxa);
    mina = min(a, mina);

    a = texture(TEXTURE, UV + vec2(-outline_width, 0.0) * ps).a;
    maxa = max(a, maxa);
    mina = min(a, mina);

    a = texture(TEXTURE, UV + vec2(outline_width, 0.0) * ps).a;
    maxa = max(a, maxa);
    mina = min(a, mina);

    // Paint the outline color only on the edges
    COLOR = mix(col, outline_color, maxa - mina);
}