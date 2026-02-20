# gpu_utils/sort.py
import numpy as np

BITONIC_SORT_SHADER_PREFIX = """
#version 430
layout(local_size_x = 64) in;

layout(std430, binding = 
"""


BITONIC_SORT_SHADER_SUFFIX = """) buffer Data {
    uvec2 pairs[];
};

uniform uint Count;
uniform uint stage;
uniform uint passNum;

void main() {
    uint i = gl_GlobalInvocationID.x;
    if (i >= Count) return;

    uint j = i ^ passNum;
    if (j > i) {
        bool ascending = (i & (stage << 1)) == 0;
        if ((pairs[i].x > pairs[j].x) == ascending) {
            uvec2 temp = pairs[i];
            pairs[i] = pairs[j];
            pairs[j] = temp;
        }
    }
}
"""

class GPUSort:
    def __init__(self, ctx, bind_point=3):
        self.ctx = ctx
        self._shader = ctx.compute_shader(BITONIC_SORT_SHADER_PREFIX + str(bind_point) + BITONIC_SORT_SHADER_SUFFIX)
        self._bind_point = bind_point

    def sort(self, buffer, count):
        """Sort a buffer of uvec2 pairs by .x ascending.
        buffer: moderngl buffer of uvec2
        count: number of pairs
        binding: which binding slot to use (default 0)
        """
        # Bitonic sort requires power of 2 count
        padded = self._next_power_of_2(count)
        if padded != count:
            self._pad_buffer(buffer, count, padded)

        buffer.bind_to_storage_buffer(self._bind_point)
        groups = int(np.ceil(padded / 64))

        stage = 1
        while stage < padded:
            p = stage
            while p >= 1:
                self._shader["Count"] = padded
                self._shader["stage"] = stage
                self._shader["passNum"] = p
                self._shader.run(group_x=groups, group_y=1, group_z=1)
                self.ctx.memory_barrier()
                p //= 2
            stage *= 2

    def _next_power_of_2(self, n):
        p = 1
        while p < n:
            p *= 2
        return p

    def _pad_buffer(self, buffer, real_count, padded_count):
        """Pad buffer with max uint values so they sort to the end"""
        extra = padded_count - real_count
        padding = np.full((extra, 2), 0xFFFFFFFF, dtype=np.uint32)
        # write padding at the end
        offset = real_count * 8  # 8 bytes per uvec2
        buffer.write(padding.tobytes(), offset=offset)