shader_type canvas_item;

// These show up in your Inspector so you can change them easily
uniform vec2 scroll_speed = vec2(0.05, 0.05);
uniform float brightness : hint_range(0.0, 2.0) = 1.0;

void fragment() {
    // TIME is a built-in Godot variable that counts up forever
    // We add it to the UV (texture coordinates) to shift the image
    vec2 shifted_uv = UV + (scroll_speed * TIME);
    
    // texture() draws the pixel, and 'repeat' makes it tile
    vec4 color = texture(TEXTURE, shifted_uv);
    
    // Apply a little sci-fi glow/brightness boost
    COLOR = color * brightness;
}