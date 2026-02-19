import moderngl_window as mglw
import moderngl as mgl
import numpy as np

print(70*"=")
print("Running! Meowwww")

TVSH = """
#version 430
in vec2 pos;

void main(){
	gl_PointSize = 3.0;
	gl_Position = vec4(pos, 0.0, 1.0);
}

"""

TFSH = """
#version 430

uniform float Time;

out vec4 fragColor;

void main(){
	fragColor = vec4(1.0, 0.0, fract(Time), 1.0);
}

"""



TCSH = """
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
	vec2 c = mouse;

	vec2 delta = c - pos;
	
	vec2 accel = 3.0 * dt * normalize(delta) / max(0.001, length(delta));
	THIS.speed += dt * accel;
	p[i] = THIS;
}
"""


class App(mglw.WindowConfig):
	title = "SandPile"
	window_size = (1080, 720)
	gl_version = (4, 3)
	
	
	
	def __init__(self, **kwargs):
		super().__init__(**kwargs)


		self.N = 500 # number of particles
		worldX = 1 # width of world
		worldY = 1 # height of world
		

		shape = (self.N, 8) #in here 8 is for 8 floats it's a matrix!
		p_data = np.zeros(shape, dtype=np.float32)

		# note first 2 indexes are the position vector, this randomizes it
		p_data[:, 0] = np.random.uniform(-worldX, worldX, self.N)
		p_data[:, 1] = np.random.uniform(-worldX, worldX, self.N)
			
		print(p_data)


		self.compute = self.ctx.compute_shader(TCSH)

		self.p_data_ssbo = self.ctx.buffer(p_data.tobytes()) # create the buffer
		self.p_data_ssbo.bind_to_storage_buffer(0); # note 0 is the same as in the compute shader

		


		# fragment test
		self.prog = self.ctx.program(vertex_shader = TVSH, fragment_shader = TFSH)

		self.mouse = (0, 0)


	def on_mouse_position_event(self, x, y, dx, dy):
		self.mouse = (x / self.window_size[0], y / self.window_size[1])
		return super().on_mouse_position_event(x, y, dx, dy)

	def on_render(self, time, frame_t):
		self.ctx.clear(0.05, 0.01, 0)
		self.prog["Time"] = time
		self.compute["Count"] = self.N
		self.compute["dt"] = frame_t
		self.compute["mouse"] = self.mouse

		
		vertex_array_content = [(self.p_data_ssbo, "2f 24x", "pos")]
		self.vao = self.ctx.vertex_array(self.prog, vertex_array_content)
		self.ctx.enable(mgl.PROGRAM_POINT_SIZE)
		self.vao.render(mgl.POINTS, vertices=self.N)

		groups = int(np.ceil(self.N / 64)) # how many groups of 64
		self.compute.run(group_x= groups, group_y=1, group_z= 1) # essentially the dimensions to run, 1d cuz particles()



















if __name__ == "__main__":
	mglw.run_window_config(App)