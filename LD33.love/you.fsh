extern number time;
extern number grabbing;

vec4 effect(vec4 color, Image texture, vec2 textureCoordinates, vec2 screenCoordinates) {
	vec2 position = textureCoordinates;
	position -= vec2(0.5);
	position.y *= (60.0 / 140.0);
	float d = distance(position, vec2(0,0.01)) - 0.11;
	vec2 adjustedTextureCoordinates = textureCoordinates;
	if(d > 0) {
		adjustedTextureCoordinates.y += sin(time * 2 * (1.0 + 1.0 * grabbing) + d * 8 + textureCoordinates.x * 5 + textureCoordinates.y * 4) * (0.4 - .1*grabbing) * d;
		adjustedTextureCoordinates.x += sin(time * 1.5 * (1.0 + 1.2 * grabbing) + d * 4 + textureCoordinates.x * 5) * 0.1 * d;
	}
	vec4 c = Texel(texture, adjustedTextureCoordinates) * color;
	return c;
}