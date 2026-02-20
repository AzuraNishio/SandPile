#version 430
layout(local_size_x = 64) in;

uniform int Count;
uniform float dt;
uniform vec2 mouse;

struct Particle{
	vec2 pos;
	vec2 speed;
	vec4 nya;
};


layout(std430, binding = 0) buffer Particles{
	Particle p[];
};

void main (){
	if (gl_GlobalInvocationID.x >= Count){
		return;
	}
	uint i = gl_GlobalInvocationID.x;
	Particle THIS = p[i];
	THIS.pos += THIS.speed * dt;

	vec2 pos = THIS.pos;
	
	vec2 accel = vec2(0.0);

	for (int i = 0; i < Count; i++){
		if(i == gl_GlobalInvocationID.x){
			continue;
		}
		Particle other = p[i];
		vec2 delta = other.pos - pos;
		float dist = length(delta);
		accel += 0.0001 * normalize(delta) / max(0.001, pow(dist, 2.0));
	}


	THIS.speed += dt * accel;

	p[i] = THIS;
}