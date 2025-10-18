KTX2 :: struct {
	Header :: struct {
		identifier 		: [12]u8;
		vk_format		: VkFormat;
		type_size		: u32;
		pixel_width		: u32;
		pixel_height	: u32;
		pixel_depth		: u32;
		layer_count		: u32;
		face_count		: u32;
		level_count		: u32;
		supercompression_scheme	: u32;
	}

	Level_Index :: struct {
		byte_offset		: u64;
		byte_length		: u64;
		uncomp_byte_length : u64; // Don't really care about this one
	}
}

load_image :: (zr: *ZRenderer, file_path: string) -> *Allocated_Image {
	new_image := import_KTX2(zr, file_path);
	new_image.image_index = xx zr.descriptor_writer.write_image(*zr.descriptor_writer, *zr.image_descriptor_buffer, new_image.image_view, .VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);
	success, left, right := split_from_right(file_path, ".");
	success, left, new_image.image_name = split_from_right(left, "/");
	return table_add(*zr.image_table, new_image.image_name, new_image);
}

import_KTX2 :: (zr: *ZRenderer, file_path: string) -> Allocated_Image {
	file_string, success := read_entire_file(file_path);
	if !success {
		print("Failed to read file at %", file_path);
		return .{};
	}

	// Header
	file_data := file_string.data;
	cursor : *u8 = file_data;
	header : KTX2.Header;
	header.identifier = <<cast(*[12]u8)cursor;
	cursor += size_of([12]u8);
	header.vk_format = <<cast(*VkFormat)cursor;
	cursor += size_of(VkFormat);
	header.type_size = <<cast(*u32)cursor;
	cursor += size_of(u32);
	header.pixel_width = <<cast(*u32)cursor;
	cursor += size_of(u32);
	header.pixel_height = <<cast(*u32)cursor;
	cursor += size_of(u32);
	header.pixel_depth = <<cast(*u32)cursor;
	if header.pixel_depth == 0 {
		header.pixel_depth = 1; // 0 is invalid for image creation
	}
	cursor += size_of(u32);
	header.layer_count = <<cast(*u32)cursor;
	cursor += size_of(u32);
	header.face_count = <<cast(*u32)cursor;
	cursor += size_of(u32);
	header.level_count = <<cast(*u32)cursor;
	cursor += size_of(u32);
	header.supercompression_scheme = <<cast(*u32)cursor;
	cursor += size_of(u32);

	// Skip Index section
	cursor += 32;

	levels	: [..]KTX2.Level_Index;
	array_resize(*levels, header.level_count);
	for 0..header.level_count-1 {
		levels[it] = <<cast(*KTX2.Level_Index)cursor;
		cursor += size_of(KTX2.Level_Index);
	}

	for 0..header.level_count-1 {
		mip_data := file_data + levels[it].byte_offset;
		mip_size := levels[it].byte_length;
	}

	size := VkExtent3D.{header.pixel_width, header.pixel_height, header.pixel_depth};
	new_image := create_image(zr, size, header.vk_format, .VK_IMAGE_USAGE_SAMPLED_BIT | .VK_IMAGE_USAGE_TRANSFER_DST_BIT, true, header.level_count, "KTX2_Tex");

	total_size : u64 = 0;
	for levels {
		total_size += it.byte_length;
	}

	upload_buffer := create_buffer(VMA_ALLOCATOR, total_size, .VK_BUFFER_USAGE_TRANSFER_SRC_BIT, .VMA_MEMORY_USAGE_CPU_TO_GPU, zr.device, "KTX2_Staging");

	buffer_offset : u64 = 0;
	for levels {
		mip_data := file_data + it.byte_offset;
		memcpy(upload_buffer.info.pMappedData + buffer_offset, mip_data, xx it.byte_length);
		buffer_offset += it.byte_length;
	}

	immediate_submit(zr, #code {
        vkutil_transition_image(cmd, new_image.image, .VK_IMAGE_LAYOUT_UNDEFINED, .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, .VK_IMAGE_ASPECT_COLOR_BIT);
        
        buffer_offset := 0;
        mip_width := header.pixel_width;
        mip_height := header.pixel_height;
        
        for 0..header.level_count-1 {
            copy_region : VkBufferImageCopy;
            copy_region.bufferOffset = xx buffer_offset;
            copy_region.bufferRowLength = 0;
            copy_region.bufferImageHeight = 0;
            copy_region.imageOffset = .{0, 0, 0};
            copy_region.imageSubresource.aspectMask = .VK_IMAGE_ASPECT_COLOR_BIT;
            copy_region.imageSubresource.mipLevel = cast(u32)it;  // Different for each mip
            copy_region.imageSubresource.baseArrayLayer = 0;
            copy_region.imageSubresource.layerCount = 1;
            copy_region.imageExtent = .{mip_width, mip_height, 1};
            
            vkCmdCopyBufferToImage(cmd, upload_buffer.buffer, new_image.image, .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, *copy_region);
            
            buffer_offset += xx levels[it].byte_length;
            mip_width = xx max(1, mip_width >> 1);
            mip_height = xx max(1, mip_height >> 1);
        }
        
        vkutil_transition_image(cmd, new_image.image,
                               .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                               .VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                               .VK_IMAGE_ASPECT_COLOR_BIT);
    });

	destroy_buffer(VMA_ALLOCATOR, *upload_buffer);

	return new_image;
}