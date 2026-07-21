shader_type canvas_item;

// Adjust this value to skew the X axis
uniform float skew_amount : hint_range(-1.0, 1.0) = -0.055;

void vertex() {
    // Shifts the vertex position based on its Y coordinate
    VERTEX.x += VERTEX.y * skew_amount;

    // Adjust UV coordinates to prevent stretching artifacts in the texture
    UV.x -= UV.y * skew_amount;
    UV.x = clamp(UV.x, 0.0, 1.0);
}

void fragment() {
	// Called for every pixel the material is visible on.
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
