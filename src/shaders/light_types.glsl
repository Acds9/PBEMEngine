struct Point_Light {
    vec3 position;
    float radius; 
    vec4 color;
};
layout(buffer_reference, scalar) readonly buffer Point_Light_Data { 
    Point_Light lights[];
};

layout(buffer_reference, scalar) buffer Light_Indices_Buffer {
    uint cluster_light_indices[];
};
