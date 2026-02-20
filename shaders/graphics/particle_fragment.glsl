#version 430

uniform float Time;

out vec4 fragColor;

void main(){
	fragColor = vec4(1.0, 0.0, sin(Time), 0.5);
}
