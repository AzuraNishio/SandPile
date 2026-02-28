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

#define particleTypeSize 0.333334

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
float yellow(Particle p){ return type(p, 2.0); }	
float red(Particle p){ return type(p, 1.0); }
float magenta(Particle p){ return type(p, 0.0); }
float redOrYellow(Particle p){ return yellow(p) + red(p); }


struct BondForce{
	float force;
	float damping;
	float dist;
	float alignForce;
	float selfTargetAngle;
	float selfAttachPointsInverse;
	float otherTargetAngle;
	float otherAttachPointsInverse;
	float tollerance;
	float fullDamping;
};

BondForce bondForcePair(Particle p, Particle other){
	float redYellow = red(p) * yellow(other);
	float yellowRed = yellow(p) * red(other);
	float yellowYellow = yellow(p) * yellow(other);
	float redRed = red(p) * red(other);
	
	

	BondForce bf;
	//translation
	bf.force = 
	((yellowYellow) * 21.0) +
	((redRed) * 21.0) +
	((redYellow + yellowRed) * 35.0);

	bf.damping = 
	((yellowYellow) * 0.5) +
	((redRed) * 4.0) +
	((redYellow + yellowRed) * 10.0);

	bf.fullDamping = 
	((yellowYellow) * 10.0) +
	((redRed) * 10.0) +
	((redYellow + yellowRed) * 4.0);

	bf.dist = 
	((yellowYellow) * 0.6) +
	((redRed) * 0.7) +
	((redYellow + yellowRed) * 0.6);
	
	//alignment
	bf.alignForce = 
	(yellowYellow * 1.5) +
	((redRed) * 1.5) +
	((redYellow + yellowRed) * 2.0);
	
	bf.selfTargetAngle = 
	(yellowYellow * (PIHALF)) +
	((redRed) * PIHALF) +
	((redYellow + yellowRed) * 0.0);

	bf.selfAttachPointsInverse = 
	(yellowYellow * 0.5) +
	((redRed) * 0.5) +
	((redYellow + yellowRed) * 1.0);

	bf.otherTargetAngle = 
	(yellowYellow * PIHALF) +
	((redRed) * PIHALF) +
	((redYellow + yellowRed) * PI);

	bf.otherAttachPointsInverse = 
	(yellowYellow * 0.5) +
	((redRed) * 0.5) +
	((redYellow + yellowRed) * 1.0);

	bf.tollerance = 
	(yellowYellow * 0.2) +
	((redRed) * 0.2) +
	((redYellow + yellowRed) * 0.1);
	

	bf.dist = max(bf.dist, 0.01);
	bf.otherAttachPointsInverse = max(bf.otherAttachPointsInverse, 0.01);
	bf.selfAttachPointsInverse = max(bf.selfAttachPointsInverse, 0.01);
	return bf;
}

struct SmoothForce{
	float force;
	float beginDist;
	float endDist;
};

SmoothForce smoothForcePair(Particle p, Particle other){
	float redMagenta = magenta(p) * red(other) + magenta(other) * red(p);
	float yellowMagenta = magenta(p) * yellow(other) + magenta(other) * yellow(p);
	float redRed = red(p) * red(other);
	float redYellow = red(p) * yellow(other) + red(other) * yellow(p);
	float magentaMagenta = magenta(p) * magenta(other);


	SmoothForce bf;

	bf.force = 
	(redMagenta * -0.1) + 
	(yellowMagenta * -0.6) +
	((redRed) * 0.00) +
	((redYellow) * 0.1) +
	((magentaMagenta) * -0.1);

	bf.beginDist = 
	(redMagenta * 0.0) + 
	(yellowMagenta * 0.0) +
	((redRed) * 0.01) +
	((redYellow) * 0.001) +
	((magentaMagenta) * 0.0);

	bf.endDist = 
	(redMagenta * 0.7) + 
	(yellowMagenta * 1.0) +
	((redRed) * 0.5) +
	((redYellow) * 0.5) +
	((magentaMagenta) * 0.7);
	

	return bf;
}


struct FlowForce{
	float viscosity;
	float beginDist;
	float endDist;
	float flow;
	float align;
};

FlowForce flowForcePair(Particle p, Particle other){
	float magentaMagenta = magenta(p) * magenta(other);

	FlowForce bf;

	bf.viscosity = 
	((magentaMagenta) * 2.0);

	bf.beginDist = 
	((magentaMagenta) * 0.0);

	bf.endDist = 
	((magentaMagenta) * 0.9);
	
	bf.flow = 
	((magentaMagenta) * 0.5);

	bf.align = 
	((magentaMagenta) * 0.1);
	

	return bf;
}

float brownianForce(Particle p){
	return (yellow(p) * 0.001) + (red(p) * 0.0) + (magenta(p) * 15.0);
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

void polarBondForce(
    in BondForce bf,
    in Particle self,
    in Particle other,
    in vec2 delta,
    in float dist,
    inout vec2 accel,
    inout float torque
){
    if(bf.force < 0.002 && bf.alignForce < 0.002) return;
	float distanceDecay = max(0.0, 1.4 - (dist / max(bf.dist, 0.05)));

	//Axial rotation alignement
	float alignement = wrapAngle((other.rotation - bf.otherTargetAngle) - (self.rotation - bf.selfTargetAngle));
	float torqueFromAlignement = smoothstep(bf.tollerance * 0.95, bf.tollerance, abs(alignement)) * alignement;
	float dotAlignement = dot(vec2FromAngle(self.rotation - bf.selfTargetAngle), vec2FromAngle(other.rotation - bf.otherTargetAngle));

	torque += torqueFromAlignement * distanceDecay * bf.alignForce;

	//Bond rotation alignement
	float bondRotation = wrapAngle(atan(delta.y, delta.x));
	float selfBondRotationError = wrapAngleFraction(bondRotation - (self.rotation - bf.selfTargetAngle), bf.selfAttachPointsInverse);
	
	vec2 forceFromBondRotation = smoothstep(bf.tollerance * 0.95, bf.tollerance, abs(selfBondRotationError)) * selfBondRotationError * vec2FromAngle(bondRotation + PIHALF) * PI2 * bf.dist;

	accel += forceFromBondRotation * distanceDecay * bf.alignForce;

	//Bond force
	dotAlignement = (step(0.0001, bf.alignForce) * ((dotAlignement - 0.1) * 2.0)) + step(bf.alignForce, 0.0001);

	vec2 bondDirection = delta / dist;
	vec2 relativeSpeed = other.speed - self.speed;
	float relativeSpeedAlongBond = dot(relativeSpeed, bondDirection);
	float distError = dist - bf.dist;

	vec2 bondForce = sign(distError) * pow(abs(distError) / bf.dist, 2.0) * bondDirection * distanceDecay * dotAlignement;
	vec2 dampingForce = relativeSpeedAlongBond * bondDirection * distanceDecay * dotAlignement;

	accel += relativeSpeed * distanceDecay * bf.fullDamping;
	accel += bondForce * bf.force;
    accel += dampingForce * bf.damping;
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
		if(length(delta) > cellSize * 1.5) return;  // too far, skip
		vec2 nDelta = normalize(delta);
		float dist = length(delta);

		//Default universal interaction
		float minDist = particleSize(self) + particleSize(other);

		if(dist < minDist && dist > 0.001){
    		float overlap = minDist - dist;
    		accel += nDelta * -overlap * 100.0 * dot(nDelta, self.speed - other.speed);
			accel += 0.25 * ((other.speed - self.speed) * 0.3);
		}

		//Bond forces
		BondForce bf = bondForcePair(self, other);
		polarBondForce(bf, self, other, delta, dist, accel, torque);
		
		//Smooth forces
		SmoothForce sf = smoothForcePair(self, other);
		float smoothStrength = smoothstep(sf.beginDist, sf.endDist, dist) * sf.force;
		accel += nDelta * smoothStrength;

		//flow forces
		FlowForce ff = flowForcePair(self, other);
		float flowStrength = smoothstep(ff.beginDist, ff.endDist, dist) * ff.viscosity;
		vec2 speedDifference = other.speed - self.speed;
		accel += speedDifference * flowStrength;
		
		float flowiness = dot(accel, selfForward);
		accel += selfForward * flowiness * ff.flow;

		torque += ff.align * ((other.rotation) - (1.0 * self.rotation)) * flowStrength;
	}

}

void main (){
	if (gl_GlobalInvocationID.x >= Count){
		return;
	}
	uint i = gl_GlobalInvocationID.x;
	Particle self = p[i];

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
	self.speed = clamp(self.speed, vec2(-6.0), vec2(6.0));

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