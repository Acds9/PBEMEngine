Deletion_Queue :: struct {
	image_views		: [..] struct {device: VkDevice; view: VkImageView;};
	images 			: [..] struct {allocator: VmaAllocator; image: VkImage; allocation: VmaAllocation;};
	desc_allocators : [..] struct {device: VkDevice; allocator: *Descriptor_Allocator;};
	desc_layouts	: [..] struct {device: VkDevice; layout: VkDescriptorSetLayout;};
	pipelines		: [..] struct {device: VkDevice; pipeline: VkPipeline;};
	pipeline_layouts: [..] struct {device: VkDevice; layout: VkPipelineLayout;};
	command_pools	: [..] struct {device: VkDevice; pool: VkCommandPool;};
	fences			: [..] struct {device: VkDevice; fence: VkFence;};
	buffers			: [..] struct {allocator: VmaAllocator; buffer: VkBuffer; allocation: VmaAllocation;};
	samplers		: [..] struct {device: VkDevice; sampler: VkSampler;};

	flush_deletion_queue :: (using self: *Deletion_Queue) {
		for <image_views {
			vkDestroyImageView(it.device, it.view, null);
		}
		for <images {
			vmaDestroyImage(it.allocator, it.image, it.allocation);
		}
		for <desc_allocators {
			it.allocator.destroy_pools(it.allocator, it.device);
		}
		for <desc_layouts {
			vkDestroyDescriptorSetLayout(it.device, it.layout, null);
		}
		for <pipeline_layouts {
			vkDestroyPipelineLayout(it.device, it.layout, null);
		}
		for <pipelines {
			vkDestroyPipeline(it.device, it.pipeline, null);
		}
		for <command_pools {
			vkDestroyCommandPool(it.device, it.pool, null);
		}
		for <fences {
			vkDestroyFence(it.device, it.fence, null);
		}
		for <buffers {
			vmaDestroyBuffer(it.allocator, it.buffer, it.allocation);
		}
		for <samplers {
			vkDestroySampler(it.device, it.sampler, null);
		}
		array_reset(*image_views);
		array_reset(*images);
		array_reset(*desc_layouts);
		array_reset(*pipeline_layouts);
		array_reset(*pipelines);
		array_reset(*command_pools);
		array_reset(*fences);
		array_reset(*buffers);
		array_reset(*samplers);
	}
}

queue_deletion :: (queue: *Deletion_Queue, device: VkDevice, view: VkImageView) {
    array_add(*queue.image_views, .{device, view});
}

queue_deletion :: (queue: *Deletion_Queue, allocator: VmaAllocator, image: VkImage, allocation: VmaAllocation) {
    array_add(*queue.images, .{allocator, image, allocation});
}

queue_deletion :: (queue: *Deletion_Queue, device: VkDevice, allocator: *Descriptor_Allocator) {
    array_add(*queue.desc_allocators, .{device, allocator});
}

queue_deletion :: (queue: *Deletion_Queue, device: VkDevice, layout: VkDescriptorSetLayout) {
    array_add(*queue.desc_layouts, .{device, layout});
}

queue_deletion :: (queue: *Deletion_Queue, device: VkDevice, pipeline: VkPipeline) {
    array_add(*queue.pipelines, .{device, pipeline});
}

queue_deletion :: (queue: *Deletion_Queue, device: VkDevice, layout: VkPipelineLayout) {
    array_add(*queue.pipeline_layouts, .{device, layout});
}

queue_deletion :: (queue: *Deletion_Queue, device: VkDevice, pool: VkCommandPool) {
    array_add(*queue.command_pools, .{device, pool});
}

queue_deletion :: (queue: *Deletion_Queue, device: VkDevice, fence: VkFence) {
    array_add(*queue.fences, .{device, fence});
}

queue_deletion :: (queue: *Deletion_Queue, allocator: VmaAllocator, buffer: VkBuffer, allocation: VmaAllocation) {
    array_add(*queue.buffers, .{allocator, buffer, allocation});
}

queue_deletion :: (queue: *Deletion_Queue, device: VkDevice, sampler: VkSampler) {
    array_add(*queue.samplers, .{device, sampler});
}