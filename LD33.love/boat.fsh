extern number progress;

vec4 effect(vec4 color, Image texture, vec2 textureCoordinates, vec2 screenCoordinates) {
	textureCoordinates.y -= progress;
	float angle = progress * -0.8;
	mat2 rotation = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
	textureCoordinates -= vec2(0.5);
	textureCoordinates = rotation * textureCoordinates;
	textureCoordinates += vec2(0.5);
	vec4 c = Texel(texture, textureCoordinates) * color;
	return c;
}