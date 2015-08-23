extern number time;
extern number multiplier;

vec4 effect(vec4 color, Image texture, vec2 textureCoordinates, vec2 screenCoordinates) {
	vec2 position = textureCoordinates;
	vec2 adjustedTextureCoordinates = textureCoordinates;
	adjustedTextureCoordinates.y += sin(time * 1.2 + textureCoordinates.x * 5 + textureCoordinates.y * 4) * .01 * multiplier;
	adjustedTextureCoordinates.x += sin(time * 0.8 + textureCoordinates.x * 5) * .005 * multiplier;
	vec4 c = Texel(texture, adjustedTextureCoordinates) * color;
	return c;
}