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