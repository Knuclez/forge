package testsito

import "vendor:sdl2"
import vk "vendor:vulkan"
import glsl "core:math/linalg/glsl"

N_ENGINE_VOXELS :: 5

Engine :: struct{
    vulkan_app : vkApplication,
    voxels : [N_ENGINE_VOXELS]Voxel,
}

Voxel :: struct{
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
    image_count : u32,
    swapchain_images : [^]vk.Image,
    swapchain_image_views : [^]vk.ImageView,


    graphics_pipeline_layout : vk.PipelineLayout, 
    graphics_pipeline : vk.Pipeline,

    main_command_pool : vk.CommandPool,
    draw_command_buffers : [^]vk.CommandBuffer,

    vertex_buffer : vk.Buffer,
    vertex_buffer_memory : vk.DeviceMemory,
    index_buffer : vk.Buffer,
    index_buffer_memory : vk.DeviceMemory,

    textures : [2]VulkanTexture,
    depth_resources : DepthResources,

    uniform_buffers : [1]vk.Buffer,
    uniform_buffers_memory : [1]vk.DeviceMemory,
    uniform_buffers_mapped : [1]rawptr,

    frame_descriptor_set_layout : vk.DescriptorSetLayout,
    frame_descriptor_pool : vk.DescriptorPool,
    frame_descriptor_sets : [1]vk.DescriptorSet,
    material_descriptor_set_layout : vk.DescriptorSetLayout,
    material_descriptor_pool : vk.DescriptorPool,
    material_descriptor_sets : [2]vk.DescriptorSet, 

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
