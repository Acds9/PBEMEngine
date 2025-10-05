Allocated_Buffer :: struct {
	buffer		: VkBuffer;
	allocation	: VmaAllocation;
	info		: VmaAllocationInfo; 
	base_address: VkDeviceAddress;
}

// Non uniform storage buffer, just an Allocated_Buffer with an offset for writing, not really meant for things to be removed from it
Storage_Buffer :: struct {
	using base	: Allocated_Buffer;
	offset		: u64;

	allocate :: (using self: *Storage_Buffer, data: *void, size: u32, aligned: bool = true) -> VkDeviceAddress {
		if offset + size > info.size {
            panic(sprint("Storage buffer out of space. Used: %, Capacity: %", offset + size, info.size));
        }
        
        // For uniform buffer requirements 
        aligned_offset := offset;
        if aligned {
			aligned_offset = (aligned_offset + 255) & ~255;
		}
        
        dest_ptr := cast,no_check(*u8)info.pMappedData + aligned_offset;
        memcpy(dest_ptr, data, size);
        
        address := base_address + aligned_offset;
        offset = aligned_offset + size;
        
        return address;
	}

	reset :: (using self: *Storage_Buffer) {
		offset = 0;
	}
}

// Specializaiton for storage of identically sized chunks e.g. copies of the same struct
Uniform_Storage_Buffer :: struct {
	using base	: Allocated_Buffer;
	element_size: u32;
	capacity	: u64;
	count		: u32;
	free_list	: [..]u32;
	generations	: [..]u8;

	allocate :: (using self: *Uniform_Storage_Buffer, value: $T, gen: *u8 = null) -> VkDeviceAddress {
		write_index : u32;
		if free_list.count > 0 {
			write_index = pop(*free_list);;
			generations[write_index] += 1;
			if gen != null then <<gen = generations[write_index];
			//gen = *generations[write_index]; TEST!!!
		}
		else {
			write_index = count;
			count += 1;
			array_resize(*generations, count);
		}

		if count >= capacity {
			panic(sprint("Attempted to allocate more transforms than capacity allows. Capacity: %", capacity));
		}

		cast_data := cast,no_check(*T)info.pMappedData;
		cast_data[write_index] = value;
		data_address := base_address + write_index * element_size;
		return data_address;
	}
	buffer_remove :: (using self: *Uniform_Storage_Buffer, address: VkDeviceAddress) {
		offset := address - base_address;
		index := cast,no_check(u32)(offset / element_size);
    
		array_add(*free_list, index);
	}
}

Linear_Buffer :: struct {
    using parent: Storage_Buffer;
    element_size: u64;

	// Allocate space for one descriptor, returns the binding offset (not address)
    allocate_descriptor :: (using self: *Linear_Buffer, alignement: u64) -> u64 {
        aligned_offset := align_up(offset, alignement);
        
        if aligned_offset + element_size > info.size {
            panic(sprint("Linear_Buffer out of space. Used: %, Capacity: %", aligned_offset + element_size, info.size));
        }
        
        binding_offset := aligned_offset / element_size;
        offset = aligned_offset + element_size;
        
        return binding_offset;
    }
	reset :: (using self: *Linear_Buffer) {
		offset = 0;
	}
}

create_buffer :: (allocator: VmaAllocator, alloc_size: u64, usage: VkBufferUsageFlags, memory_usage: VmaMemoryUsage, device: VkDevice = null, debug_name: string = "") -> Allocated_Buffer {
	buffer_info : VkBufferCreateInfo;
	buffer_info.sType = .VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
	buffer_info.size = alloc_size;

	buffer_info.usage = usage;

	vma_alloc_info : VmaAllocationCreateInfo;
	vma_alloc_info.usage = memory_usage;
	vma_alloc_info.flags = .VMA_ALLOCATION_CREATE_MAPPED_BIT;
	
	new_buffer : Allocated_Buffer;
	result := vmaCreateBuffer(allocator, *buffer_info, *vma_alloc_info, *new_buffer.buffer, *new_buffer.allocation, *new_buffer.info);
	if result != .VK_SUCCESS {
		print("ERROR: could not create memory buffer\n");
		debug_break();
	}

	// Only get device address if the buffer supports it
    if (usage & .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT) {
        address_info := VkBufferDeviceAddressInfo.{
            sType = .VK_STRUCTURE_TYPE_BUFFER_DEVICE_ADDRESS_INFO,
            buffer = new_buffer.buffer,
        };
        new_buffer.base_address = vkGetBufferDeviceAddress(device, *address_info);
    } else {
        new_buffer.base_address = 0;  
    }

	if ENABLE_VALIDATION_LAYERS {
		if device == null || debug_name == "" {
			panic("ERROR: VkDevice or vk_debug_name not set for buffer in debug\n");
		}
		set_vk_object_name(device, .BUFFER, cast(u64)new_buffer.buffer, debug_name);
	}
	return new_buffer;
}

make_storage_buffer :: (allocator: VmaAllocator, alloc_size: u64, usage: VkBufferUsageFlags, memory_usage: VmaMemoryUsage, device: VkDevice = null, debug_name: string = "") -> Storage_Buffer {
	new_buffer : Storage_Buffer;
	allocated_buffer := create_buffer(allocator, alloc_size, usage, memory_usage, device, debug_name);
	new_buffer.buffer = allocated_buffer.buffer;
	new_buffer.allocation = allocated_buffer.allocation;
	new_buffer.info = allocated_buffer.info;
	new_buffer.base_address = allocated_buffer.base_address;
	new_buffer.offset = 0;
	return new_buffer;
}

make_uniform_storage_buffer :: (allocator: VmaAllocator, alloc_size: u64, element_size: u32, usage: VkBufferUsageFlags, memory_usage: VmaMemoryUsage, device: VkDevice = null, debug_name: string = "") -> Uniform_Storage_Buffer {
	new_buffer : Uniform_Storage_Buffer;
	allocated_buffer := create_buffer(allocator, alloc_size, usage, memory_usage, device, debug_name);
	new_buffer.buffer = allocated_buffer.buffer;
	new_buffer.allocation = allocated_buffer.allocation;
	new_buffer.info = allocated_buffer.info;
	new_buffer.base_address = allocated_buffer.base_address;
	new_buffer.element_size = element_size;
	new_buffer.capacity = alloc_size/element_size;
	return new_buffer;
}

make_linear_buffer :: (allocator: VmaAllocator, alloc_size: u64, element_size: u32, usage: VkBufferUsageFlags, memory_usage: VmaMemoryUsage, device: VkDevice = null, debug_name: string = "") -> Linear_Buffer {
	new_buffer : Linear_Buffer;
	storage_buffer := make_storage_buffer(allocator, alloc_size, usage, memory_usage, device, debug_name);
	new_buffer.buffer 		= storage_buffer.buffer;
	new_buffer.allocation 	= storage_buffer.allocation;
	new_buffer.info 		= storage_buffer.info;
	new_buffer.base_address = storage_buffer.base_address;
	new_buffer.offset 		= 0;
	new_buffer.element_size = element_size;
	return new_buffer;
}

destroy_buffer :: (allocator: VmaAllocator, buffer: *Allocated_Buffer) {
	vmaDestroyBuffer(allocator, buffer.buffer, buffer.allocation);
}
destroy_buffer :: (allocator: VmaAllocator, buffer: *Storage_Buffer) {
	vmaDestroyBuffer(allocator, buffer.buffer, buffer.allocation);
}
destroy_buffer :: (allocator: VmaAllocator, buffer: *Uniform_Storage_Buffer) {
	vmaDestroyBuffer(allocator, buffer.buffer, buffer.allocation);
}