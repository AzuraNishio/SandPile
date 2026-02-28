#version 430
in vec2 pos;
in vec4 data;

out vec4 fData;

uniform vec2 cameraPos;
uniform float zoom;
uniform vec2 screenSize;

void main(){
	float fuzzy = smoothstep(0.019, 0.014, zoom);
	gl_PointSize = ((30.0 * 10.0 * zoom) * (1.0 - fuzzy)) + ((fuzzy) * 7.0);
	vec2 newPos = (pos / screenSize) * screenSize.y;

	gl_Position = vec4((newPos - cameraPos) * zoom, 0.0, 1.0);
	fData = data;
}
