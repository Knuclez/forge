package testsito

import "vendor:sdl2"
import vk "vendor:vulkan"
import glsl "core:math/linalg/glsl"

Application :: struct {
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
    image_count : u32,
    images : [^]vk.Image,
    image_views : [^]vk.ImageView,

    descriptor_set_layout : vk.DescriptorSetLayout,

    render_pass : vk.RenderPass,
    graphics_pipeline_layout : vk.PipelineLayout, 
    graphics_pipeline : vk.Pipeline,

    framebuffers : [^]vk.Framebuffer,
    main_command_pool : vk.CommandPool,
    draw_command_buffers : [^]vk.CommandBuffer,

    vertex_buffer : vk.Buffer,
    vertex_buffer_memory : vk.DeviceMemory,
    index_buffer : vk.Buffer,
    index_buffer_memory : vk.DeviceMemory,

    uniform_buffers : [1]vk.Buffer,
    uniform_buffers_memory : [1]vk.DeviceMemory,
    uniform_buffers_mapped : [1]rawptr,

    descriptor_pool : vk.DescriptorPool,
    descriptor_sets : [1]vk.DescriptorSet,

    in_flight_fence : vk.Fence,
    image_available_semaphore : vk.Semaphore,
    render_finished_semaphore : vk.Semaphore,
}

Vertex :: struct {
    pos : glsl.vec2,
    color : glsl.vec3,
}

GlobalTransformUBO :: struct {
    model : glsl.vec4,
    view : glsl.vec4,
    proj : glsl.vec4,
}
