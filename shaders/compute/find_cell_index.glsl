#version 430
layout(local_size_x = 64) in;

uniform int Count;

layout(std430, binding = 1) buffer ParticleGridPairs{
	uvec2 pairs[];
};

layout(std430, binding = 2) buffer CellStartIndexes{
	uint startIndexes[];
};

void main (){
	if (gl_GlobalInvocationID.x >= Count){
		return;
	}
	uint i = gl_GlobalInvocationID.x;
	
	if (i == 0){
		startIndexes[0] = 0;
	} else {
		uvec2 THIS = pairs[i];
		uvec2 LAST = pairs[i - 1];

		if (THIS.x != LAST.x){
			startIndexes[THIS.x] = i;
		}
	}
}