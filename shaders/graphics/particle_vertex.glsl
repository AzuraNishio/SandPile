#version 430
in vec2 pos;
uniform vec2 cameraPos;
uniform float zoom;
uniform vec2 screenSize;

void main(){
	gl_PointSize = 2.0;
	vec2 newPos = (pos / screenSize) * screenSize.y;
	gl_Position = vec4((newPos - cameraPos) * zoom, 0.0, 1.0);
}
