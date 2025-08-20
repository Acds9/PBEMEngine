#import "GL";
#import "Math";
vertex_shader_source : string;
vertex_shader_source_initialized := false;
vertex_shader : u32;

frag_shader_source : string;
frag_shader_source_initialized := false;
frag_shader : u32;

shader_program : u32;

VBO : u32;
VAO : u32;
EBO : u32;

V_SCALE :: 1.5;
v_translation_idx : s32;

vertices :: Vector3.[
	.{-0.5, -0.5, 0.0},
	.{0.0, 0.5, 0.0},
	.{0.5, -0.5, 0.0},
];
/*
vertices ::  float.[
	0.0,  0.0, 0.0,  	// top right
	0.5,  0.0, 0.0,
	0.5,  0.0, 0.0,
];*/ 
indices :: u32.[
	0,1,3,
	1,2,3
];

init_rendering :: () -> bool, string {
	glViewport(0, 0, xx WINDOW_WIDTH, xx WINDOW_HEIGHT);

	glGenBuffers(1, *VBO);
	glBindBuffer(GL_ARRAY_BUFFER, VBO);
	glBufferData(GL_ARRAY_BUFFER, size_of_array(vertices), *vertices, GL_STATIC_DRAW);

	
	/////////////
	// SHADERS //
	/////////////
	shader_program = glCreateProgram();
	if shader_program == 0 return false, "Error creating shader program";

	// Vertex Shader Setup
	vertex_shader_source := read_entire_file("src/shaders/vshader.vert");
	
	vertex_shader_obj := glCreateShader(GL_VERTEX_SHADER);
	if vertex_shader_obj == 0 return false, "Error creating vertex shader";
	//defer glDeleteShader(vertex_shader_obj);

	glShaderSource(vertex_shader_obj, 2, *vertex_shader_source.data, *cast,no_check(s32)vertex_shader_source.count);

	glCompileShader(vertex_shader_obj);

	vertex_success : s32;
	glGetShaderiv(vertex_shader_obj, GL_COMPILE_STATUS, *vertex_success);
	if !vertex_success {
		info_len : s32;
		glGetShaderiv (vertex_shader_obj, GL_INFO_LOG_LENGTH, *info_len);
		info_data := cast (*u8) alloc (info_len,, temp);
		glGetShaderInfoLog (vertex_shader_obj, xx info_len, xx *info_len, info_data);
		return false, to_string(info_data);
	}

	glAttachShader(shader_program, vertex_shader_obj);

	// Fragment Shader Setup
	fragment_shader_source := read_entire_file("src/shaders/fragshader.frag");

	fragment_shader_obj := glCreateShader(GL_FRAGMENT_SHADER);
	if fragment_shader_obj == 0 return false, "Error creating fragment shader";
	//defer glDeleteShader(fragment_shader_obj);
	
	glShaderSource(fragment_shader_obj, 2, *fragment_shader_source.data, *cast,no_check(s32)fragment_shader_source.count);

	glCompileShader(fragment_shader_obj);

	fragment_success : s32;
	glGetShaderiv(fragment_shader_obj, GL_COMPILE_STATUS, *fragment_success);
	if !fragment_success {
		info_len : s32;
		glGetShaderiv (fragment_shader_obj, GL_INFO_LOG_LENGTH, *info_len);
		info_data := cast (*u8) alloc (info_len,, temp);
		glGetShaderInfoLog (fragment_shader_obj, xx info_len, xx *info_len, info_data);
		return false, to_string(info_data);
	}
	
	glAttachShader(shader_program, fragment_shader_obj);

	// Program Setup
	glLinkProgram(shader_program);

	link_success : s32;
	glGetProgramiv(shader_program, GL_LINK_STATUS, *link_success);
	if !link_success {
		info_len : s32 = 1024;
		glGetShaderiv(shader_program, GL_INFO_LOG_LENGTH, *info_len);
		info_data := cast (*u8) alloc (info_len,, temp);
		glGetProgramInfoLog(shader_program, xx info_len, xx *info_len, info_data);
		return false, to_string(info_data);
	}

	glValidateProgram(shader_program);
	glGetProgramiv(shader_program, GL_VALIDATE_STATUS, *link_success);
	if !link_success {
		info_len : s32;
		glGetShaderiv (shader_program, GL_INFO_LOG_LENGTH, *info_len);
		info_data := cast (*u8) alloc (info_len,, temp);
		glGetProgramInfoLog (shader_program, xx info_len, xx *info_len, info_data);
		return false, to_string(info_data);
	}

	v_translation_idx = glGetUniformLocation(shader_program, "gTranslation");
	if v_translation_idx == -1 {
		return false, "v_translation_idx invalid";
	}

	glUseProgram(shader_program);
	return true, "";
}

acc : float;
draw_frame :: (window: *SDL_Window) {
    glClear(GL_COLOR_BUFFER_BIT);

	acc += 0.01;
	
	translation : Matrix4 = .{	1, 0, 0, acc,
								0, 1, 0, acc,
								0, 0, 1, acc,
								0, 0, 0, 1};

	glUniformMatrix4fv(v_translation_idx, 1, GL_TRUE, *translation._11);
	//glUniform1f(v_scale_idx, acc);
	glBindBuffer(GL_ARRAY_BUFFER, VBO);
	glEnableVertexAttribArray(0);
	glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(float)*3, null);

	glDrawArrays(GL_TRIANGLES, 0, 3);
	glDisableVertexAttribArray(0);

	SDL_GL_SwapWindow(window); 
}

deinit_rendering :: () {
	glDeleteVertexArrays(1, *VAO);
    glDeleteBuffers(1, *VBO);
    //glDeleteBuffers(1, &EBO);
    glDeleteProgram(shader_program);
}