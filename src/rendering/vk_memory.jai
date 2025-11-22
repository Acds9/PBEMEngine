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

	allocate :: (using self: *Uniform_Storage_Buffer, value: $T) -> VkDeviceAddress {
		write_index : u32;
		if free_list.count > 0 {
			write_index = pop(*free_list);;
			generations[write_index] += 1;
		}
		else {
			write_index = count;
			count += 1;
			array_resize(*generations, count);
		}

		if count >= capacity {
			panic(sprint("Attempted to allocate more elements than capacity allows. Capacity: %", capacity));
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
	reset :: (using self: *Uniform_Storage_Buffer) {
		array_reset(*free_list);
		array_reset(*generations);
		count = 0;
	}
}

Staged_Uniform_Storage_Buffer :: struct {
	staging_buffer 	: Allocated_Buffer; // CPU memory
	device_buffer	: Allocated_Buffer; // GPU memory
	// The following are the same for both so they are shared
	element_size: u32;
	capacity	: u64;
	count		: u32;
	free_list	: [..]u32;
	generations	: [..]u8;

	allocate :: (using self: *Staged_Uniform_Storage_Buffer, value: $T) -> VkDeviceAddress {
		write_index : u32;
		if free_list.count > 0 {
			write_index = pop(*free_list);;
			generations[write_index] += 1;
		}
		else {
			write_index = count;
			count += 1;
			array_resize(*generations, count);
		}

		if count >= capacity {
			panic(sprint("Attempted to allocate more elements than capacity allows. Capacity: %", capacity));
		}

		cast_data := cast,no_check(*T)staging_buffer.info.pMappedData;
		cast_data[write_index] = value;
		
		address := staging_buffer.base_address + write_index * element_size;
		return address;
	}

	transfer :: (using self: *Staged_Uniform_Storage_Buffer, cmd: VkCommandBuffer) {
		copy : VkBufferCopy;
		copy.size = count * element_size;
		if copy.size == 0 {
			return;
		}
		vkCmdCopyBuffer(cmd, staging_buffer.buffer, device_buffer.buffer, 1, *copy);
	}

	get_device_address :: (using self: *Staged_Uniform_Storage_Buffer, address: VkDeviceAddress) -> VkDeviceAddress {
		return device_buffer.base_address + (address - staging_buffer.base_address);
	}

	buffer_remove :: (using self: *Staged_Uniform_Storage_Buffer, address: VkDeviceAddress) {
		offset := address - staging_buffer.base_address;
		index := cast,no_check(u32)(offset / element_size);
		array_add(*free_list, index);
	}
	
	reset :: (using self: *Staged_Uniform_Storage_Buffer) {
		array_reset(*free_list);
		array_reset(*generations);
		count = 0;
	}
}

Linear_Buffer :: struct {
    using parent: Storage_Buffer;
    element_size: u64;

	// Allocate space for one descriptor, returns the binding offset (not address)
    allocate_descriptor :: (using self: *Linear_Buffer, alignement: u64) -> u64 {
        if offset + element_size > info.size {
            panic(sprint("Linear_Buffer out of space. Used: %, Capacity: %", offset + element_size, info.size));
        }
        
        binding_offset := offset / element_size;
        offset +=  element_size;
        
        return binding_offset;
    }
	reset :: (using self: *Linear_Buffer) {
		offset = 0;
	}
}

// Intended to be used as a bitfield
Bitfield_Buffer :: struct {
	using base: Allocated_Buffer;

	set_bit :: (using self: *Bitfield_Buffer, bit: u64, value: bool) {
		words := cast,no_check(*u32) info.pMappedData;
        word_index := bit / 32;
        bit_pos := cast,no_check(u32)(bit % 32);
        
        if value {
            words[word_index] |= cast,no_check(u32)(1 << bit_pos);
        } else {
            words[word_index] &= ~cast,no_check(u32)(1 << bit_pos);
        }
	}
	get_bit :: (using self: *Bitfield_Buffer, bit: u64) -> bool {
		words := cast,no_check(*u32) info.pMappedData;
        word_index := bit / 32;
        bit_pos := cast,no_check(u32)(bit % 32);
        
        return (words[word_index] & (1 << bit_pos)) != 0;
	}
}

// Meant for writing straight into, e.g. draw command buffers
Staged_Array_Buffer :: struct {
    staging_buffer  : Allocated_Buffer;
    device_buffer   : Allocated_Buffer;
    element_size    : u32;
    capacity        : u32;
    count           : u32;
    
    get_staging_ptr :: (using self: *Staged_Array_Buffer, $T: Type) -> *T {
        assert(size_of(T) == element_size);
        return cast(*T) staging_buffer.info.pMappedData;
    }

	allocate :: (using self: *Staged_Array_Buffer, value: $T) -> VkDeviceAddress {
		write_index := count;
		if count >= capacity {
			panic(sprint("Attempted to allocate more elements than capacity allows. Capacity: %", capacity));
		}
		count += 1;
		
		cast_data := cast,no_check(*T)staging_buffer.info.pMappedData;
		cast_data[write_index] = value;
		
		address := staging_buffer.base_address + write_index * element_size;

		return address;
	}
    
    transfer :: (using self: *Staged_Array_Buffer, cmd: VkCommandBuffer) {
        if count == 0 return;
        
        copy : VkBufferCopy;
        copy.size = count * element_size;
        vkCmdCopyBuffer(cmd, staging_buffer.buffer, device_buffer.buffer, 1, *copy);
    }

	reset :: (using self: *Staged_Array_Buffer) {
        count = 0;
    }
}

// For single struct buffers that NEED low access latency of device memory
Staged_Struct_Buffer :: struct {
	staging_buffer  : Allocated_Buffer;
    device_buffer   : Allocated_Buffer;
	size			: u32;

	allocate :: (using self: *Staged_Struct_Buffer, value: $T) -> VkDeviceAddress {
		cast_data := cast,no_check(*T)staging_buffer.info.pMappedData;
		cast_data[0] = value;

		return staging_buffer.base_address;
	}
    
    transfer :: (using self: *Staged_Struct_Buffer, cmd: VkCommandBuffer) {
        copy : VkBufferCopy;
        copy.size = size;
        vkCmdCopyBuffer(cmd, staging_buffer.buffer, device_buffer.buffer, 1, *copy);
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
	return .{
		base = create_buffer(allocator, alloc_size, usage, memory_usage, device, debug_name)
	};
}

make_uniform_storage_buffer :: (allocator: VmaAllocator, alloc_size: u64, element_size: u32, usage: VkBufferUsageFlags, memory_usage: VmaMemoryUsage, device: VkDevice = null, debug_name: string = "") -> Uniform_Storage_Buffer {
	return .{
		base = create_buffer(allocator, alloc_size, usage, memory_usage, device, debug_name),
		element_size = element_size,
		capacity = alloc_size/element_size
	};
}

make_staged_uniform_storage_buffer :: (allocator: VmaAllocator, alloc_size: u64, element_size: u32, usage: VkBufferUsageFlags, device: VkDevice = null, debug_name: string = "") -> Staged_Uniform_Storage_Buffer {
	staging_name := sprint("%_%", debug_name, "staging");
	device_name := sprint("%_%", debug_name, "device");
	return .{
		staging_buffer = create_buffer(allocator, alloc_size, .VK_BUFFER_USAGE_TRANSFER_SRC_BIT | usage, .CPU_ONLY, device, staging_name),
		device_buffer = create_buffer(allocator, alloc_size, .VK_BUFFER_USAGE_TRANSFER_DST_BIT | usage, .GPU_ONLY, device, device_name),
		element_size = element_size,
		capacity = alloc_size/element_size
	};
}

make_linear_buffer :: (allocator: VmaAllocator, alloc_size: u64, element_size: u32, usage: VkBufferUsageFlags, memory_usage: VmaMemoryUsage, device: VkDevice = null, debug_name: string = "") -> Linear_Buffer {
	return .{
		base = create_buffer(allocator, alloc_size, usage, memory_usage, device, debug_name),
		element_size = element_size
	};
}

make_bitfield_buffer :: (allocator: VmaAllocator, num_bits: u64, usage: VkBufferUsageFlags, memory_usage: VmaMemoryUsage, device: VkDevice = null, debug_name: string = "") -> Bitfield_Buffer {
	alloc_size : u64 = xx ceil(cast,no_check(float)num_bits / 8.0);
	return .{
			base = create_buffer(allocator, alloc_size, usage, memory_usage, device, debug_name)
		};
}

make_staged_array_buffer :: (allocator: VmaAllocator, alloc_size: u64, element_size: u32, usage: VkBufferUsageFlags, device: VkDevice = null, debug_name: string = "") -> Staged_Array_Buffer {
	staging_name := sprint("%_%", debug_name, "staging");
	device_name := sprint("%_%", debug_name, "device");
	return .{
		staging_buffer = create_buffer(allocator, alloc_size, .VK_BUFFER_USAGE_TRANSFER_SRC_BIT | usage, .CPU_ONLY, device, staging_name),
		device_buffer = create_buffer(allocator, alloc_size, .VK_BUFFER_USAGE_TRANSFER_DST_BIT | usage, .GPU_ONLY, device, device_name),
		element_size = element_size,
		capacity = xx alloc_size/element_size
	};
}

make_staged_struct_buffer :: (allocator: VmaAllocator, alloc_size: u32, usage: VkBufferUsageFlags, device: VkDevice = null, debug_name: string = "") -> Staged_Struct_Buffer {
	staging_name := sprint("%_%", debug_name, "staging");
	device_name := sprint("%_%", debug_name, "device");
	
	return .{
		staging_buffer = create_buffer(allocator, alloc_size, .VK_BUFFER_USAGE_TRANSFER_SRC_BIT | usage, .CPU_ONLY, device, staging_name),
		device_buffer = create_buffer(allocator, alloc_size, .VK_BUFFER_USAGE_TRANSFER_DST_BIT | usage, .GPU_ONLY, device, device_name),
		size = alloc_size
	};
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


