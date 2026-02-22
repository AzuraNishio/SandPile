#version 430

uniform float Time;
uniform float zoom;

in vec4 fData;

out vec4 fragColor;

#define particleTypeSize 0.333334

vec4 col(vec4 col, float n)
{	
	return (step(fData.x, (n * particleTypeSize) + particleTypeSize) - step(fData.x, (n * particleTypeSize))) * col;
}


void main(){
	vec2 coord = gl_PointCoord - 0.5;
	coord.y *= -1.0;

	vec4 bColor = vec4(0.0);
	bColor += col(vec4(1.0, 0.3, 1.0, 0.5), 0.0);
	bColor += col(vec4(1.0, 0.3, 0.3, 0.75), 1.0);
	bColor += col(vec4(1.0, 1.0, 0.3, 0.9), 2.0);

	vec4 color = bColor;

	float closeDetails = smoothstep(0.002, 0.2, zoom);
	float fuzzy = smoothstep(0.019, 0.014, zoom);
	float fuzzyZoom = zoom / 0.01;

	float size = color.a;

	coord = vec2(
		coord.x * sin(fData.y) - coord.y * cos(fData.y),
		coord.x * cos(fData.y) + coord.y * sin(fData.y)
	);

	vec2 rezizedCoord = coord / (size - (0.15 * closeDetails));

	color.rgb -= (pow(length(rezizedCoord), 2.0) * 5.0) * closeDetails;
	color.rgb -= min(0.0, rezizedCoord.y - 0.15) * 2.0;
	color.rgb -= min(max(0.0, rezizedCoord.y + 0.1) * 20.0, 0.1);
	
	rezizedCoord.y -= min(0.0, rezizedCoord.y) + step(0.2, -rezizedCoord.y);

	color.rgb = mix(color.rgb, normalize(color.rgb * color.rgb + vec3(0.1, 0.0, 0.1)) * 0.6, smoothstep(0.47, 0.5, 2.0 * length(rezizedCoord)));


	vec2 rezizedCoord2 = coord / size;
	rezizedCoord2.y -= min(0.0, rezizedCoord2.y) + step(0.2, -rezizedCoord2.y);
	
	color.a = smoothstep(0.5, 0.45, 2.0 * length(rezizedCoord2));


	color *= 1.0 - fuzzy;
	color.rgb += fuzzy * bColor.rgb;

	float fuzzyDist = length((coord * vec2(1.0, 0.8)) / (1.0 + (0.6 * (fuzzyZoom - 1.0))));
	float fuzzyAlpha = (size * 0.18) / fuzzyDist;

	color.a += min(0.8, 1.4 * (fuzzyAlpha - 0.5)) * fuzzy;
	color.rgb -= 0.5 * fuzzy;
	color.rgb += step(rezizedCoord2.y, 0.0) * 0.9 * fuzzy;


	fragColor = color;
}
