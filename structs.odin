package testsito

import "vendor:sdl2"
import vk "vendor:vulkan"
import glsl "core:math/linalg/glsl"

Engine :: struct{
    //engine
    looping : bool,

    //rendering
    vulkan_app : vkApplication,
    
    //camera
    view_transform : Object3D,
    projection_transform : glsl.mat4,

    //world
    map_chunks : [N_CHUNKS]MapChunk,
    voxels : [N_VOXELS+1]Voxel,
}


IdKey::struct{
    id : u32,
    gen : u32,
}


MapChunk::struct{
    position : glsl.vec3,
    data : [CHUNK_WIDTH][CHUNK_WIDTH][CHUNK_HEIGHT]IdKey,
}


Voxel::struct{
    key : IdKey,
    using obj3D : Object3D,
}

Object3D::struct{
    position : glsl.mat4,
    rotation : glsl.mat4,
    scale : glsl.mat4,
    model : glsl.mat4,
}


//VULKAN STRUCTS
vkApplication :: struct {
    is_debug_mode : bool,
    vk_debug_messenger : vk.DebugUtilsMessengerEXT, 

    window: ^sdl2.Window,
    surface : vk.SurfaceKHR,
    instance : vk.Instance,

    physical_device : vk.PhysicalDevice,
    graphics_queue_family_index : u32,
    graphics_queue : vk.Queue,
    device : vk.Device,

    swapchain : vk.SwapchainKHR,
    swapchain_image_extent : vk.Extent2D,
    swapchain_image_count : u32,
    swapchain_images : [^]vk.Image,
    swapchain_image_views : [^]vk.ImageView,

    main_command_pool : vk.CommandPool,
    draw_command_buffers : [^]vk.CommandBuffer,

    //GENERAL RESOURCES (MULTIPLE PIPELINES)
    depth_resources : DepthResources,

    frame_descriptor_set_layout : vk.DescriptorSetLayout,
    frame_descriptor_pool : vk.DescriptorPool,
    frame_descriptor_sets : [1]vk.DescriptorSet,
    uniform_buffers : [1]vk.Buffer,
    uniform_buffers_memory : [1]vk.DeviceMemory,
    uniform_buffers_mapped : [1]rawptr,

    //GRID PIPELINES
    grid_gp_layout : vk.PipelineLayout, 
    grid_gp : vk.Pipeline,
    grid_vertex_buffer : vk.Buffer,
    grid_vertex_buffer_memory : vk.DeviceMemory,
    grid_index_buffer : vk.Buffer,
    grid_index_buffer_memory : vk.DeviceMemory,

    //NOT RENAMED TO MAINTAIN BACKWARD-COMPAT
    //this is voxels pipeline
    graphics_pipeline_layout : vk.PipelineLayout, 
    graphics_pipeline : vk.Pipeline,
    vertex_buffer : vk.Buffer,
    vertex_buffer_memory : vk.DeviceMemory,
    index_buffer : vk.Buffer,
    index_buffer_memory : vk.DeviceMemory,
    textures : [2]VulkanTexture,

    material_descriptor_set_layout : vk.DescriptorSetLayout,
    material_descriptor_pool : vk.DescriptorPool,
    material_descriptor_sets : [2]vk.DescriptorSet, 

    //SYNC
    in_flight_fence : vk.Fence,
    image_available_semaphore : vk.Semaphore,
    render_finished_semaphore : vk.Semaphore,
}


DepthResources :: struct {
    image : vk.Image,
    image_view : vk.ImageView,
    memory : vk.DeviceMemory,
    format : vk.Format,
}

VulkanTexture :: struct {
    t_image : vk.Image,
    t_memory : vk.DeviceMemory,
    t_image_view : vk.ImageView,
    t_sampler : vk.Sampler,
}

Vertex :: struct {
    pos : glsl.vec3,
    color : glsl.vec3,
    tex_coords : glsl.vec2,
}

GlobalTransformUBO :: struct {
    model : glsl.mat4,
    view : glsl.mat4,
    proj : glsl.mat4,
}
