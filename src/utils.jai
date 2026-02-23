#import "File";
#import "String";
#import "File_Utilities";

// Files
file_list_ext :: (folder: string, extension: string, recursive: bool = false, follow_directory_symlinks : bool = true) -> [..]string {
	src_files := file_list(folder, recursive, follow_directory_symlinks);
	filtered_files : [..]string;

	for file: src_files {
		if !ends_with(file, sprint("%", extension)) continue;
		array_add(*filtered_files, file);
	}
	return filtered_files;
}

array_contains :: (array: []$T, value: T) -> bool { // TODO: use array_find
	for array {
		if it == value 
			return true;
	}
	return false;
}

array_add_unique :: (array: *[..]$T, value: T) -> bool {
	if array_contains(<<array, value)
		return false;
	array_add(array, value);
	return true;
}

string_to_byte_array :: (str: string) -> [..]u8 {
	bytes: [..]u8;
	for str {
		array_add(*bytes, it);
	} 
	return bytes;
}

panic :: (msg: string) {
	print("%\n", msg);
	debug_break();
}

panic_no_name :: (object: string) {
	print("ERROR: No name set for % but we are in debug mode\n", object);
	debug_break();
}

get_mip_levels :: (width: u32, height: u32) -> u32 {
    size := max(width, height);
    if size == 0 return 0;
    
    // Find position of highest set bit
    level: u32 = 0;
    while size > 1 {
        size >>= 1;
        level += 1;
    }
    return level + 1;
}

align_up :: (value: u64, alignment: u64) -> u64 {
    return (value + alignment - 1) & ~(alignment - 1);
}

subslice :: (src: [..]u8, offset: s64, count: s64) -> []u8 {
	assert(src.count <= offset + count, tprint("ERROR: Attempted to subslice past the end of an array. Array count: %, Subslice range: % - %", src.count, offset, offset + count));
	result : []u8;
	result.data = src.data + offset;
	result.count = count;
	return result;
}

