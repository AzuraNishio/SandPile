#version 430
layout(local_size_x = 64) in;

uniform uint gridWidth;
uniform float cellSize;
uniform int Count;

struct Particle{
	vec2 pos;
	vec2 speed;
	vec4 nya;
};


layout(std430, binding = 0) buffer Particles{
	Particle p[];
};

layout(std430, binding = 1) buffer ParticleGridPairs{
	uvec2 pairs[];
};

void main (){
	if (gl_GlobalInvocationID.x >= Count){
		return;
	}
	uint i = gl_GlobalInvocationID.x;
	Particle THIS = p[i];
	
	uint gridID = uint(clamp(THIS.pos.x / cellSize, 0.0, float(gridWidth - 1u))) + 
              uint(clamp(THIS.pos.y / cellSize, 0.0, float(gridWidth - 1u))) * gridWidth;


	// Store the particle-grid pair in the buffer
	pairs[i] = uvec2(gridID, i);
}