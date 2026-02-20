import moderngl_window as mglw
import moderngl as mgl
import numpy as np
import utills.GPUSort as sort

print(70*"=")
print("Running! Meowwww")


class SandPileWindow(mglw.WindowConfig):
	title = "SandPile"
	window_size = (1280, 720)
	gl_version = (4, 3)
	
	N = 10000 # number of particles
	world_size = (10.0, 10.0) # the world will be from -world_size to +world_size in both x and y
	cell_size = 0.5 # size of the grid cells for THE GRIIID

	def setup_shaders(self):
		# load the shader files as strings
		self.ParticleComputeString = open("shaders/compute/particle_physics_compute.glsl").read()
		self.ParticleComputeAssignGrid = open("shaders/compute/assign_particle_cell.glsl").read()
		self.FindCellIndex = open("shaders/compute/find_cell_index.glsl").read()

		self.ParticleFragmentString = open("shaders/graphics/particle_fragment.glsl").read()
		self.ParticleVertexString = open("shaders/graphics/particle_vertex.glsl").read()

		# create the shaders and programs
		self.physics_csh = self.ctx.compute_shader(self.ParticleComputeString)
		self.assign_grid_csh = self.ctx.compute_shader(self.ParticleComputeAssignGrid)
		self.find_cell_index_csh = self.ctx.compute_shader(self.FindCellIndex)

		self.particle_sh = self.ctx.program(vertex_shader = self.ParticleVertexString, fragment_shader = self.ParticleFragmentString)

	def setup_buffers(self):
		# Particle data buffer
		self.padded_N = self.sorter._next_power_of_2(self.N)
		shape = (self.padded_N, 8) #in here 8 is for 8 floats it's a matrix!
		p_data = np.zeros(shape, dtype=np.float32)

		# note first 2 indexes are the position vector, this randomizes it
		p_data[:self.N, 0] = np.random.uniform(-self.world_size[0], self.world_size[0], self.N)
		p_data[:self.N, 1] = np.random.uniform(-self.world_size[1], self.world_size[1], self.N)
		speed = 0.1;
		p_data[:self.N, 2] = np.random.uniform(-speed, speed, self.N)
		p_data[:self.N, 3] = np.random.uniform(-speed, speed, self.N)

		self.particle_data_ssbo = self.ctx.buffer(p_data.tobytes()) # create the buffer
		self.particle_data_ssbo.bind_to_storage_buffer(0); # note 0 is the same as in the compute shader
	
		# grid pos pairs
		shape = (self.padded_N, 2) #in here 2 is for 2 uints
		particle_grid_pairs = np.zeros(shape, dtype=np.uint32)

		self.particle_grid_pairs_ssbo = self.ctx.buffer(particle_grid_pairs.tobytes()) # create the buffer
		self.particle_grid_pairs_ssbo.bind_to_storage_buffer(1); 
	
		# grid cell start indexes
		shape = (self.padded_N, 1) #in here 2 is for 2 uints
		cell_start_indexes = np.zeros(shape, dtype=np.uint32)

		self.cell_start_indexes_ssbo = self.ctx.buffer(cell_start_indexes.tobytes()) # create the buffer
		self.cell_start_indexes_ssbo.bind_to_storage_buffer(2); 
	
	def setup_camera(self):
		self.camera_pos = (0, 0)
		self.zoom = 0.8/max(self.world_size)
		self.moving_up = False
		self.moving_down = False
		self.moving_left = False
		self.moving_right = False


	def __init__(self, **kwargs):
		super().__init__(**kwargs)

		self.sorter = sort.GPUSort(self.ctx, 3);
		
		self.setup_shaders()
		self.setup_buffers()
		self.setup_camera()

		#self.run_grid_assignement()

		self.mouse = (0, 0)

		vertex_array_content = [(self.particle_data_ssbo, "2f 24x", "pos")]
		self.vao = self.ctx.vertex_array(self.particle_sh, vertex_array_content)
		self.ctx.enable(mgl.PROGRAM_POINT_SIZE)




	def on_mouse_position_event(self, x, y, dx, dy):
		self.mouse = (((x / self.window_size[0]) * 2) - 1, ((y / self.window_size[1] * -2) + 1))
		return super().on_mouse_position_event(x, y, dx, dy)
	
	def on_key_event(self, key, action, modifiers):
		if action == self.wnd.keys.ACTION_PRESS:
			if key == self.wnd.keys.W:
				self.moving_up = True
			if key == self.wnd.keys.S:
				self.moving_down = True
			if key == self.wnd.keys.A:
				self.moving_left = True
			if key == self.wnd.keys.D:
				self.moving_right = True
		if action == self.wnd.keys.ACTION_RELEASE:
			if key == self.wnd.keys.W:
				self.moving_up = False
			if key == self.wnd.keys.S:
				self.moving_down = False
			if key == self.wnd.keys.A:
				self.moving_left = False
			if key == self.wnd.keys.D:
				self.moving_right = False
		return super().on_key_event(key, action, modifiers)


	def run_grid_assignement(self):	
		self.assign_grid_csh["Count"] = self.N
		self.assign_grid_csh["gridWidth"] = int(self.world_size[0] * 2 / self.cell_size)
		self.assign_grid_csh["cellSize"] = self.cell_size

		groups = int(np.ceil(self.N / 64)) # how many groups of 64
		self.assign_grid_csh.run(group_x= groups, group_y=1, group_z= 1)
		self.ctx.memory_barrier()
		self.sorter.sort(self.particle_grid_pairs_ssbo, self.N)
		self.ctx.memory_barrier()

		groups = int(np.ceil((self.world_size[0] * 2 / self.cell_size) * (self.world_size[1] * 2 / self.cell_size) / 64)) # how many groups of 64
		self.find_cell_index_csh.run(group_x= groups, group_y=1, group_z= 1)
		self.ctx.memory_barrier()



	def run_compute_shader(self, time, delta_t):	
		self.physics_csh["Count"] = self.N
		self.physics_csh["dt"] = delta_t
		# self.physics_csh["gridWidth"] = int(self.world_size[0] * 2 / self.cell_size)
		# self.physics_csh["cellSize"] = self.cell_size
		# self.compute["mouse"] = self.mouse

		groups = int(np.ceil(self.N / 64)) # how many groups of 64
		self.physics_csh.run(group_x= groups, group_y=1, group_z= 1) # essentially the dimensions to run, 1d cuz particles()
		self.ctx.memory_barrier()

	def move_camera(self, delta_t):
		speed = 100.0 * self.zoom
		if self.moving_up:
			self.camera_pos = (self.camera_pos[0], self.camera_pos[1] + speed * delta_t)
		if self.moving_down:
			self.camera_pos = (self.camera_pos[0], self.camera_pos[1] - speed * delta_t)
		if self.moving_left:
			self.camera_pos = (self.camera_pos[0] - speed * delta_t, self.camera_pos[1])
		if self.moving_right:
			self.camera_pos = (self.camera_pos[0] + speed * delta_t, self.camera_pos[1])

	def on_render(self, time, delta_t):
		self.ctx.clear(0.05, 0.01, 0)
		self.particle_sh["Time"] = time
		self.particle_sh["zoom"] = self.zoom
		self.particle_sh["cameraPos"] = self.camera_pos
		self.particle_sh["screenSize"] = self.window_size

		self.move_camera(delta_t)

		for i in range(1): 
			#self.run_grid_assignement()
			self.run_compute_shader(time, delta_t)

		self.vao.render(mgl.POINTS, vertices=self.N)


















if __name__ == "__main__":
	mglw.run_window_config(SandPileWindow)