#import "File";
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

size_of_array :: (array: []$T) -> u32 {
	return cast,no_check(u32)(size_of(T) * array.count);
}

array_contains :: (array: []$T, value: T) -> bool {
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