#version 430
layout(local_size_x = 64) in;

uniform int Count;
uniform float dt;
uniform float Time;
uniform vec2 mouse;
uniform vec2 worldSize;
uniform uint gridWidth;
uniform float cellSize;

#define PI 3.1415926535897932384626433832795
#define PI2 6.283185307179586476925286766559
#define PIHALF 1.5707963267948966192313216916398

#define particleTypeSize 0.25

struct Particle{
	vec2 pos;
	vec2 speed;
	float type;
	float rotation;
	float rotationSpeed;
	float nya;
};

layout(std430, binding = 0) buffer Particles{ Particle p[]; };
layout(std430, binding = 1) buffer ParticleGridPairs{ uvec2 pairs[]; };
layout(std430, binding = 2) buffer CellStartIndexes{ uint startIndexes[]; };

float hash11(float p) {
 uint u = floatBitsToUint(p * 3141592653.0);
 return float(u * u * 3141592653u) / float(~0u);
}

float hash12(vec2 p) {
 uvec2 u = floatBitsToUint(p * vec2(141421356, 2718281828));
 return float((u.x ^ u.y) * 3141592653u) / float(~0u);
}

uint cellDisplace(int x, int y, uint cell){
    int cx = int(cell % gridWidth) + x;
    int cy = int(cell / gridWidth) + y;
    uint w = gridWidth;
    cx = ((cx % int(w)) + int(w)) % int(w);
    cy = ((cy % int(w)) + int(w)) % int(w);
    return uint(cx + cy * int(w));
}

float type(Particle p, float n){ return step(p.type, (n * particleTypeSize) + particleTypeSize) - step(p.type, (n * particleTypeSize)); }
float yellow(Particle p){ return type(p, 3.0); }	
float red(Particle p){ return type(p, 1.0); }
float magenta(Particle p){ return type(p, 2.0); }
float green(Particle p){ return type(p, 0.0); }



float brownianForce(Particle p){
	return (yellow(p) * 1.0) + (red(p) * 0.0) + (magenta(p) * 10.0) + (green(p) * 100.0);
}

float particleSize(Particle p){
	return 
	(yellow(p) * 0.15) + 
	(red(p) * 0.08) + 
	(magenta(p) * 0.06);
}

vec2 vec2FromAngle(float angle){
	return vec2(cos(angle), sin(angle));
}

vec2 forward(Particle p){
	return vec2FromAngle(p.rotation);
}

vec2 right(Particle p){
	return vec2FromAngle(p.rotation + PIHALF); // 90 degrees in radians
}

float wrapAngle(float a){
    return mod(a + PI, PI2) - PI;
}

float wrapAngleFraction(float a, float fraction){
    return mod(a + (PI * fraction), PI2 * fraction) - (PI * fraction);
}

void reaction(inout Particle a, inout Particle b, float dist, float r1, float r2, float p1, float p2, float maxDist){
	float reacted = type(a, r1) * type(b, r2) * step(dist, maxDist);
	a.type = (((p1 + 0.001) * particleTypeSize) * reacted) + (a.type * (1.0 - reacted));
	b.type = (((p1 + 0.001) * particleTypeSize) * reacted) + (b.type * (1.0 - reacted));
}

void react(inout Particle a, inout Particle b, float dist){
	reaction(a, b, dist,
		0.0, 1.0, //reagents
		1.0, 1.0, //products
		1.5 //max dist
	);
}







void processCell(in uint cellId, inout Particle self, inout vec2 accel, inout float torque, in vec2 selfForward){
	uint startIndex = startIndexes[cellId];
	if(startIndex == 0xFFFFFFFF) return;
	int safety = 0;
    
	for (uint j = startIndex; pairs[j].x == cellId && j < Count; j++){
		if(safety++ > 1000) break;
		uint pId = pairs[j].y;
		if(pId == gl_GlobalInvocationID.x){
			continue;
		}

		//Setup
		Particle other = p[pId];
		vec2 delta = other.pos - self.pos;
		delta = mod(delta + worldSize * 0.5, worldSize) - worldSize * 0.5;
		if(length(delta) > cellSize * 1.5) continue;  // too far, skip
		vec2 nDelta = normalize(delta);
		float dist = length(delta);

		react(self, other, dist);

		//Default universal interaction
		float minDist = particleSize(self) + particleSize(other);

		if(dist < minDist && dist > 0.001){
    		float overlap = minDist - dist;
    		accel += nDelta * -overlap * 100.0 * dot(nDelta, self.speed - other.speed);
			accel += 0.25 * ((other.speed - self.speed) * 0.3);
		}

	}

}

void setParticleType(inout Particle p){
	p.type = abs(p.type) * 0.25003;
}


void main (){
	if (gl_GlobalInvocationID.x >= Count){
		return;
	}
	uint i = gl_GlobalInvocationID.x;
	Particle self = p[i];

	if (self.type < 0){
		setParticleType(self);
	}
	uint gridID = uint(clamp(self.pos.x / cellSize, 0.0, float(gridWidth - 1u))) + 
              uint(clamp(self.pos.y / cellSize, 0.0, float(gridWidth - 1u))) * gridWidth;
	
	vec2 accel = vec2(0.0);

	vec2 forwardVec = forward(self);
	float torque = .0;

	processCell(gridID, self, accel, torque, forwardVec);
	processCell(cellDisplace(1, 0, gridID), self, accel, torque, forwardVec);
	processCell(cellDisplace(0, 1, gridID), self, accel, torque, forwardVec);
	processCell(cellDisplace(-1, 0, gridID), self, accel, torque, forwardVec);
	processCell(cellDisplace(0, -1, gridID), self, accel, torque, forwardVec);
	processCell(cellDisplace(1, -1, gridID), self, accel, torque, forwardVec);
	processCell(cellDisplace(-1, 1, gridID), self, accel, torque, forwardVec);
	processCell(cellDisplace(1, 1, gridID), self, accel, torque, forwardVec);
	processCell(cellDisplace(-1, -1, gridID), self, accel, torque, forwardVec);

	//Brownian
	accel += (vec2(hash12((self.pos.yx * 599.0) + vec2(0.1 + (Time * 999.0), 0.1)), hash12((self.pos * 999.0) + vec2(100.0, 0.2 + Time * 999.0))) - 0.5) * brownianForce(self);
	torque += hash12((self.pos.yx * 59.0) + vec2(0.1 + (Time * 999.0), 0.1)) * 0.1 * brownianForce(self);

	//Acceleration
	self.speed += dt * accel;
	self.speed = clamp(self.speed, vec2(-7.0), vec2(7.0));

	//Torque
	self.rotationSpeed += torque * dt;
	self.rotationSpeed = clamp(self.rotationSpeed, -10.0, 10.0);

	// Drag
	self.speed *= pow(0.4, dt);
	self.rotationSpeed *= pow(0.2, dt);

	//Speed
	self.pos = fract(((self.pos + (self.speed * dt))) / worldSize) * worldSize; 
	
	//Angular speed
	self.rotation = mod(self.rotation + (self.rotationSpeed * dt), PI2);

	p[i] = self;
}