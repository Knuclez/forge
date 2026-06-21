package testsito

import "core:fmt"
import "core:os"
import "core:image/jpeg"
import "core:image/png"
import "core:mem"
import "core:time"
import "core:math/linalg/glsl"
import "base:intrinsics"
import "vendor:sdl2"
import vk "vendor:vulkan"

WINDOW_WIDTH :: 1000
WINDOW_HEIGHT :: 800
VERTEX_SHADER_PATH :: "shaders/vert.spv"
FRAGMENT_SHADER_PATH :: "shaders/frag.spv"
N_VERTEX_BINDINGS :: 1
N_VERTEX_ATTRIBUTES :: 3
N_VERTICES :: 8
N_INDICES :: 12
MAX_FRAMES_IN_FLIGHT :: 1
MAX_TEXTURES :: 2

draw_frame::proc(app : ^Application, current_time : f32){
    vk.WaitForFences(app.device, 1 , &app.in_flight_fence, true, max(u64))
    vk.ResetFences(app.device, 1, &app.in_flight_fence)

    image_index : u32
    vk.AcquireNextImageKHR(app.device, app.swapchain, max(u64),app.image_available_semaphore, {}, &image_index)

    vk.ResetCommandBuffer(app.draw_command_buffers[image_index], {})
    record_draw_command_buffer_dynamic(app, app.draw_command_buffers[image_index], image_index)

    update_global_transform_UBO(app, current_time)
    wait_semaphores : [1]vk.Semaphore = {app.image_available_semaphore}
    wait_stages : [1]vk.PipelineStageFlags = {{vk.PipelineStageFlag.COLOR_ATTACHMENT_OUTPUT}}

    submit_info : vk.SubmitInfo
    submit_info.sType = vk.StructureType.SUBMIT_INFO
    submit_info.waitSemaphoreCount = 1
    submit_info.pWaitSemaphores = raw_data(&wait_semaphores)
    submit_info.pWaitDstStageMask = raw_data(&wait_stages)
    submit_info.commandBufferCount = 1
    submit_info.pCommandBuffers = &app.draw_command_buffers[image_index]
    submit_info.signalSemaphoreCount = 1
    submit_info.pSignalSemaphores = &app.render_finished_semaphore
    if vk.QueueSubmit(app.graphics_queue, 1, &submit_info, app.in_flight_fence) != vk.Result.SUCCESS {
	fmt.println("Failed to submit draw command buffer on frame_draw")
    }

    swapchains : [1]vk.SwapchainKHR = {app.swapchain}
    present_info : vk.PresentInfoKHR
    present_info.sType = vk.StructureType.PRESENT_INFO_KHR
    present_info.waitSemaphoreCount = 1
    //present_info.pWaitSemaphores = raw_data(&wait_semaphores)
    present_info.pWaitSemaphores = &app.render_finished_semaphore
    present_info.swapchainCount = 1
    present_info.pSwapchains = raw_data(&swapchains)
    present_info.pImageIndices = &image_index
    present_info.pResults = nil

    vk.QueuePresentKHR(app.graphics_queue, &present_info)
}

update_global_transform_UBO::proc(app : ^Application, current_time : f32){
    ubo : GlobalTransformUBO
    //ubo.model = glsl.mat4(1.0)
    ubo.model = rotate_y_mat4(glsl.mat4(1.0), current_time/500)
    ubo.view = glsl.mat4(1.0)
    ubo.proj = glsl.mat4(1.0)    

    //fmt.printf("The memory address is: 0x%X\n", uintptr(&ubo))
    intrinsics.mem_copy(app.uniform_buffers_mapped[0], &ubo, size_of(ubo))
}

//=========== CREATIONS/INITIALIZATIONS/CLEAN UP ============================================
init_sdl::proc(app : ^Application){
    res := sdl2.CreateWindow("Titel", 30, 30, WINDOW_WIDTH, WINDOW_HEIGHT, {sdl2.WindowFlag.VULKAN})
    if res == nil{
	fmt.println("Fallo al crear la ventana en init_sdl")
	return
    }
    app.window = res 
}


init_vulkan::proc(app : ^Application) {
    vk_get_proc_addr := sdl2.Vulkan_GetVkGetInstanceProcAddr()
    if vk_get_proc_addr == nil {
	fmt.println("Fallo al obtener vkGetInstanceProcAddr")
	return
    }
    vk.load_proc_addresses_global(vk_get_proc_addr)


    vertex_binding_descriptions : [N_VERTEX_BINDINGS]vk.VertexInputBindingDescription
    vertex_attribute_descriptions : [N_VERTEX_ATTRIBUTES]vk.VertexInputAttributeDescription

    create_instance(app) 
    create_logical_device(app)
    create_surface(app)
    create_swapchain(app)
    prepare_vertex_binding_descriptions(&vertex_binding_descriptions)
    prepare_vertex_attribute_descriptions(&vertex_attribute_descriptions)
    prepare_frame_descriptor_set_layout(app)
    prepare_material_descriptor_set_layout(app)
    create_main_command_pool(app)
    create_draw_command_buffers(app)
    create_test_texture(app)
    create_test_texture2(app)
    create_depth_resources(app)
    create_vertex_buffer(app)
    create_index_buffer(app)
    create_global_transform_UBO(app)
    instantiate_frame_descriptor_sets(app)
    instantiate_material_descriptor_sets(app)
    create_pipeline(app, &vertex_binding_descriptions, &vertex_attribute_descriptions)
    create_sync_objects(app)
}


clean_up_vulkan::proc(app : ^Application){
    //sync dinge
    vk.DestroySemaphore(app.device, app.render_finished_semaphore, nil)
    vk.DestroySemaphore(app.device, app.image_available_semaphore, nil)
    vk.DestroyFence(app.device, app.in_flight_fence, nil)

    vk.DestroyImageView(app.device, app.depth_resources.image_view, nil)
    vk.DestroyImage(app.device, app.depth_resources.image, nil)
    vk.FreeMemory(app.device, app.depth_resources.memory, nil)

    vk.DestroySampler(app.device, app.textures[0].t_sampler, nil)
    vk.DestroyImageView(app.device, app.textures[0].t_image_view, nil)
    vk.DestroyImage(app.device, app.textures[0].t_image, nil)
    vk.FreeMemory(app.device, app.textures[0].t_memory, nil)
    free(app.draw_command_buffers)
    free(app.swapchain_images)
}


prepare_vertex_binding_descriptions::proc(vertex_binding_descriptions : ^[N_VERTEX_BINDINGS]vk.VertexInputBindingDescription){
    vertex_binding_descriptions[0].binding = 0;
    vertex_binding_descriptions[0].stride = u32(size_of(Vertex))
    vertex_binding_descriptions[0].inputRate = vk.VertexInputRate.VERTEX
}


prepare_vertex_attribute_descriptions::proc(vertex_attribute_descriptions : ^[N_VERTEX_ATTRIBUTES]vk.VertexInputAttributeDescription){
    vertex_attribute_descriptions[0].binding = 0
    vertex_attribute_descriptions[0].location = 0
    vertex_attribute_descriptions[0].format = vk.Format.R32G32B32_SFLOAT
    vertex_attribute_descriptions[0].offset = u32(offset_of(Vertex, pos))

    vertex_attribute_descriptions[1].binding = 0
    vertex_attribute_descriptions[1].location = 1
    vertex_attribute_descriptions[1].format = vk.Format.R32G32B32_SFLOAT
    vertex_attribute_descriptions[1].offset = u32(offset_of(Vertex, color))

    vertex_attribute_descriptions[2].binding = 0
    vertex_attribute_descriptions[2].location = 2
    vertex_attribute_descriptions[2].format = vk.Format.R32G32_SFLOAT
    vertex_attribute_descriptions[2].offset = u32(offset_of(Vertex, tex_coords))
}


prepare_frame_descriptor_set_layout::proc(app : ^Application){
    uniform_buffer_layout_binding : vk.DescriptorSetLayoutBinding
    uniform_buffer_layout_binding.binding = 0
    uniform_buffer_layout_binding.descriptorType = vk.DescriptorType.UNIFORM_BUFFER
    uniform_buffer_layout_binding.descriptorCount = 1
    uniform_buffer_layout_binding.stageFlags = {vk.ShaderStageFlag.VERTEX}

    ds_bindings : [1]vk.DescriptorSetLayoutBinding = {uniform_buffer_layout_binding}

    descriptor_set_layout_info : vk.DescriptorSetLayoutCreateInfo
    descriptor_set_layout_info.sType = vk.StructureType.DESCRIPTOR_SET_LAYOUT_CREATE_INFO
    descriptor_set_layout_info.bindingCount = 1
    descriptor_set_layout_info.pBindings = raw_data(&ds_bindings)
    res := vk.CreateDescriptorSetLayout(app.device, &descriptor_set_layout_info, nil, &app.frame_descriptor_set_layout)
    if res != vk.Result.SUCCESS {
	fmt.println("Error creating/preparint descriptor_set_layout")
    }
}


prepare_material_descriptor_set_layout::proc(app : ^Application){
    sampler_layout_binding : vk.DescriptorSetLayoutBinding
    sampler_layout_binding.binding = 0
    sampler_layout_binding.descriptorType = vk.DescriptorType.COMBINED_IMAGE_SAMPLER
    sampler_layout_binding.descriptorCount = 1
    sampler_layout_binding.pImmutableSamplers = nil
    sampler_layout_binding.stageFlags = {vk.ShaderStageFlag.FRAGMENT}

    ds_bindings : [1]vk.DescriptorSetLayoutBinding = {sampler_layout_binding}

    descriptor_set_layout_info : vk.DescriptorSetLayoutCreateInfo
    descriptor_set_layout_info.sType = vk.StructureType.DESCRIPTOR_SET_LAYOUT_CREATE_INFO
    descriptor_set_layout_info.bindingCount = 1
    descriptor_set_layout_info.pBindings = raw_data(&ds_bindings)
    res := vk.CreateDescriptorSetLayout(app.device, &descriptor_set_layout_info, nil, &app.material_descriptor_set_layout)
    if res != vk.Result.SUCCESS {
	fmt.println("Error creating/preparint material_descriptor_set_layout")
    }
}


create_global_transform_UBO::proc(app : ^Application){
    size : vk.DeviceSize= size_of(GlobalTransformUBO)
    buffer_create_info : vk.BufferCreateInfo
    buffer_create_info.sType = vk.StructureType.BUFFER_CREATE_INFO
    buffer_create_info.size = size
    buffer_create_info.usage = {vk.BufferUsageFlag.UNIFORM_BUFFER}
    buffer_create_info.sharingMode = vk.SharingMode.EXCLUSIVE
    property_flags : vk.MemoryPropertyFlags
    property_flags = {vk.MemoryPropertyFlag.HOST_VISIBLE,vk.MemoryPropertyFlag.HOST_COHERENT}
    create_vk_buffer(app, &app.uniform_buffers[0], &buffer_create_info, &app.uniform_buffers_memory[0], property_flags)

    vk.MapMemory(app.device, app.uniform_buffers_memory[0], 0, size, {}, &app.uniform_buffers_mapped[0])
}

instantiate_frame_descriptor_sets::proc(app : ^Application){
    //Create descriptor_pool (we have the UBO and the sampler for texture so size 2)
    descriptor_pool_sizes : [1]vk.DescriptorPoolSize
    descriptor_pool_sizes[0].type = vk.DescriptorType.UNIFORM_BUFFER
    descriptor_pool_sizes[0].descriptorCount = MAX_FRAMES_IN_FLIGHT

    descriptor_pool_create_info : vk.DescriptorPoolCreateInfo
    descriptor_pool_create_info.sType = vk.StructureType.DESCRIPTOR_POOL_CREATE_INFO
    descriptor_pool_create_info.poolSizeCount = 1
    descriptor_pool_create_info.pPoolSizes = raw_data(&descriptor_pool_sizes)
    descriptor_pool_create_info.maxSets = u32(MAX_FRAMES_IN_FLIGHT)

    if vk.CreateDescriptorPool(app.device, &descriptor_pool_create_info, nil, &app.frame_descriptor_pool) != vk.Result.SUCCESS {
	fmt.println("Error creating descriptor pool")
    }

    //Create descriptor_sets
    descriptor_allocation_info : vk.DescriptorSetAllocateInfo
    descriptor_allocation_info.sType = vk.StructureType.DESCRIPTOR_SET_ALLOCATE_INFO
    descriptor_allocation_info.descriptorPool = app.frame_descriptor_pool
    descriptor_allocation_info.descriptorSetCount = 1
    descriptor_allocation_info.pSetLayouts = &app.frame_descriptor_set_layout

    if vk.AllocateDescriptorSets(app.device, &descriptor_allocation_info, raw_data(&app.frame_descriptor_sets)) != vk.Result.SUCCESS{
	fmt.println("Error allocating descriptor_sets")
    }

    descriptor_buffer_info : vk.DescriptorBufferInfo
    descriptor_buffer_info.buffer = app.uniform_buffers[0]
    descriptor_buffer_info.offset = 0
    descriptor_buffer_info.range = size_of(GlobalTransformUBO)


    descriptor_writes : [1]vk.WriteDescriptorSet
    descriptor_writes[0].sType = vk.StructureType.WRITE_DESCRIPTOR_SET
    descriptor_writes[0].dstSet = app.frame_descriptor_sets[0]
    descriptor_writes[0].dstBinding = 0
    descriptor_writes[0].dstArrayElement = 0
    descriptor_writes[0].descriptorType = vk.DescriptorType.UNIFORM_BUFFER
    descriptor_writes[0].descriptorCount = 1
    descriptor_writes[0].pBufferInfo = &descriptor_buffer_info

    vk.UpdateDescriptorSets(app.device, 1, raw_data(&descriptor_writes), 0, nil)
}




instantiate_material_descriptor_sets::proc(app : ^Application){
    descriptor_pool_sizes : [1]vk.DescriptorPoolSize
    descriptor_pool_sizes[0].type = vk.DescriptorType.COMBINED_IMAGE_SAMPLER
    descriptor_pool_sizes[0].descriptorCount = MAX_TEXTURES 

    descriptor_pool_create_info : vk.DescriptorPoolCreateInfo
    descriptor_pool_create_info.sType = vk.StructureType.DESCRIPTOR_POOL_CREATE_INFO
    descriptor_pool_create_info.poolSizeCount = 1
    descriptor_pool_create_info.pPoolSizes = raw_data(&descriptor_pool_sizes)
    descriptor_pool_create_info.maxSets = u32(MAX_TEXTURES)

    if vk.CreateDescriptorPool(app.device, &descriptor_pool_create_info, nil, &app.material_descriptor_pool) != vk.Result.SUCCESS {
	fmt.println("Error creating descriptor pool")
    }

    set_layouts : [2]vk.DescriptorSetLayout = {app.material_descriptor_set_layout, 
	app.material_descriptor_set_layout}
    //Create descriptor_sets
    descriptor_allocation_info : vk.DescriptorSetAllocateInfo
    descriptor_allocation_info.sType = vk.StructureType.DESCRIPTOR_SET_ALLOCATE_INFO
    descriptor_allocation_info.descriptorPool = app.material_descriptor_pool
    descriptor_allocation_info.descriptorSetCount = 2
    descriptor_allocation_info.pSetLayouts = raw_data(&set_layouts)

    if vk.AllocateDescriptorSets(app.device, &descriptor_allocation_info, raw_data(&app.material_descriptor_sets)) != vk.Result.SUCCESS{
	fmt.println("Error allocating descriptor_sets")
    }

    descriptor1_image_info : vk.DescriptorImageInfo
    descriptor1_image_info.imageLayout = vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL
    descriptor1_image_info.imageView = app.textures[0].t_image_view
    descriptor1_image_info.sampler = app.textures[0].t_sampler

    descriptor2_image_info : vk.DescriptorImageInfo
    descriptor2_image_info.imageLayout = vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL
    descriptor2_image_info.imageView = app.textures[1].t_image_view
    descriptor2_image_info.sampler = app.textures[1].t_sampler

    descriptor_writes : [2]vk.WriteDescriptorSet
    descriptor_writes[0].sType = vk.StructureType.WRITE_DESCRIPTOR_SET
    descriptor_writes[0].dstSet = app.material_descriptor_sets[0]
    descriptor_writes[0].dstBinding = 0
    descriptor_writes[0].dstArrayElement = 0
    descriptor_writes[0].descriptorType = vk.DescriptorType.COMBINED_IMAGE_SAMPLER
    descriptor_writes[0].descriptorCount = 1
    descriptor_writes[0].pImageInfo = &descriptor1_image_info

    descriptor_writes[1].sType = vk.StructureType.WRITE_DESCRIPTOR_SET
    descriptor_writes[1].dstSet = app.material_descriptor_sets[1]
    descriptor_writes[1].dstBinding = 0
    descriptor_writes[1].dstArrayElement = 0
    descriptor_writes[1].descriptorType = vk.DescriptorType.COMBINED_IMAGE_SAMPLER
    descriptor_writes[1].descriptorCount = 1
    descriptor_writes[1].pImageInfo = &descriptor2_image_info

    vk.UpdateDescriptorSets(app.device, 2, raw_data(&descriptor_writes), 0, nil)
}


create_instance:: proc(app : ^Application) {
    //instance_version
    instance_version : u32
    vk.EnumerateInstanceVersion(&instance_version)
    major := vk.API_VERSION_MAJOR(instance_version)
    minor := vk.API_VERSION_MINOR(instance_version)
    patch := vk.API_VERSION_PATCH(instance_version)
    fmt.printf("Vulkan supports v: %d.%d.%d\n", major, minor, patch)
    if minor < 3 {
	fmt.println("No code branch for less than api 1.3")
	return
    }

    instance_extensions_count : u32
    ext_res := sdl2.Vulkan_GetInstanceExtensions(app.window, &instance_extensions_count, nil)

    instance_extensions := make([dynamic]cstring, instance_extensions_count)
    defer delete(instance_extensions)

    sdl2.Vulkan_GetInstanceExtensions(app.window, &instance_extensions_count, raw_data(instance_extensions))
    if ext_res == false{
	fmt.println("sdl extensions get failed when initializn vulkan")
	fmt.println(sdl2.GetError())
	return
    }

    layer_prop_count : u32
    vk.EnumerateInstanceLayerProperties(&layer_prop_count, nil)
    layer_properties := make([dynamic]vk.LayerProperties, layer_prop_count)
    defer delete(layer_properties)

    vk.EnumerateInstanceLayerProperties(&layer_prop_count, raw_data(layer_properties))

    if app.is_debug_mode{
	instance_extensions_count += 1
	append(&instance_extensions, cstring("VK_EXT_debug_utils"))
    }

    app_info : vk.ApplicationInfo
    app_info.sType = vk.StructureType.APPLICATION_INFO
    app_info.pApplicationName = "testsito"
    app_info.applicationVersion = 1
    app_info.pEngineName = "FireOdin"
    app_info.engineVersion = 1
    app_info.apiVersion = instance_version

    instance_create_info : vk.InstanceCreateInfo
    instance_create_info.sType = vk.StructureType.INSTANCE_CREATE_INFO
    instance_create_info.pApplicationInfo = &app_info 
    instance_create_info.enabledExtensionCount = instance_extensions_count
    instance_create_info.ppEnabledExtensionNames = raw_data(instance_extensions)

    if app.is_debug_mode{
	fmt.println("Debug mode on")
	khronos_layer : cstring = "VK_LAYER_KHRONOS_validation"
	instance_create_info.enabledLayerCount = 1
	instance_create_info.ppEnabledLayerNames = &khronos_layer 
    }

    res : vk.Result = vk.CreateInstance(&instance_create_info, nil, &app.instance)
    if res != vk.Result.SUCCESS{
	fmt.println(res)
	return
    }

    vk.load_proc_addresses_instance(app.instance)
}


create_logical_device::proc(app : ^Application) { 
    //find amount of compatible GPUs
    ph_device_count : u32 = 0
    vk.EnumeratePhysicalDevices(app.instance, &ph_device_count, nil)
    if ph_device_count == 0 {
	fmt.println("Failed to find GPUS with Vulkan support")
	return
    }

    //Retreive compatible GPUs and assign phyisical_device to first compatible device
    ph_devices := make([^]vk.PhysicalDevice, ph_device_count)
    vk.EnumeratePhysicalDevices(app.instance, &ph_device_count, ph_devices)

    physical_device : vk.PhysicalDevice 
    device_features : vk.PhysicalDeviceFeatures2 
    device_features.sType = vk.StructureType.PHYSICAL_DEVICE_FEATURES_2
    for i in 0..< ph_device_count{
	if(physical_device == nil){
	    physical_device = ph_devices[i]
	    vk.GetPhysicalDeviceFeatures2(physical_device, &device_features)
	    //fmt.println(device_features.dynamicRendering)
	    break
	}
    } 
    free(ph_devices)
    app.physical_device = physical_device

    //Investigate PhDevice QueueFamilies
    queue_fam_count : u32 = 0
    vk.GetPhysicalDeviceQueueFamilyProperties(app.physical_device, &queue_fam_count, nil)
    if (queue_fam_count == 0){
	fmt.println("No QueueFamilie found for Device creation when consulting Phyisical Device")
    }
    queue_fams := make([^]vk.QueueFamilyProperties, queue_fam_count)
    vk.GetPhysicalDeviceQueueFamilyProperties(app.physical_device, &queue_fam_count, queue_fams)

    //Retreive GRAPHICS_q_fam index
    for fam_indx:u32 = 0; fam_indx < queue_fam_count ; fam_indx+=1{
	if vk.QueueFlag.GRAPHICS in queue_fams[fam_indx].queueFlags{
	    app.graphics_queue_family_index = fam_indx
	    break
	}
    }
    free(queue_fams)

    //Investigate PhDecive extensions
    device_extension_count : u32 = 0
    vk.EnumerateDeviceExtensionProperties(app.physical_device, nil, &device_extension_count, nil)
    if (queue_fam_count== 0){
	fmt.println("No ExtensionProperties found for Device creation when consulting Phyisical Device")
    }
    device_extensions := make([^]vk.ExtensionProperties, device_extension_count)
    defer free(device_extensions)
    vk.EnumerateDeviceExtensionProperties(app.physical_device,nil, &device_extension_count, device_extensions)

    //Check if swapchain extension is found
    swapchain_extension_found : bool = false
    for i:u32= 0; i < device_extension_count ; i += 1 {
	ext_name := slice_string_until_null(&device_extensions[i].extensionName)
	if(vk.KHR_SWAPCHAIN_EXTENSION_NAME == ext_name) {
	    swapchain_extension_found = true
	}
    }
    if !swapchain_extension_found {
	fmt.println("Swapchain extension not found when creating logical device")
	return
    }

    //create extension list
    enabled_extension_names := []cstring{vk.KHR_SWAPCHAIN_EXTENSION_NAME}
    queue_prio : f32 = 1.0

    device_queue_create_info : vk.DeviceQueueCreateInfo
    device_queue_create_info.sType = vk.StructureType.DEVICE_QUEUE_CREATE_INFO
    device_queue_create_info.queueFamilyIndex = app.graphics_queue_family_index
    device_queue_create_info.queueCount = 1
    device_queue_create_info.pQueuePriorities = &queue_prio
    
    dynamic_rendering_features : vk.PhysicalDeviceVulkan13Features
    dynamic_rendering_features.sType = vk.StructureType.PHYSICAL_DEVICE_VULKAN_1_3_FEATURES
    dynamic_rendering_features.dynamicRendering = true

    device_create_info : vk.DeviceCreateInfo
    device_create_info.sType = vk.StructureType.DEVICE_CREATE_INFO
    device_create_info.pNext = &dynamic_rendering_features
    device_create_info.queueCreateInfoCount = 1
    device_create_info.pQueueCreateInfos = &device_queue_create_info
    device_create_info.enabledExtensionCount = 1
    device_create_info.ppEnabledExtensionNames = raw_data(enabled_extension_names)
    device_create_info.enabledLayerCount = 0
    device_create_info.ppEnabledLayerNames = nil

    dev_create_res : vk.Result = vk.CreateDevice(physical_device, &device_create_info, nil, &app.device)
    if dev_create_res != vk.Result.SUCCESS{
	fmt.println(dev_create_res)
	fmt.println("Error creating LogicalDevice")
	return
    }

    //assign queue handles in app
    vk.GetDeviceQueue(app.device, app.graphics_queue_family_index, 0, &app.graphics_queue)
}


create_surface::proc(app : ^Application){
    sfc_res : sdl2.bool = sdl2.Vulkan_CreateSurface(app.window, app.instance, &app.surface)
    if sfc_res == false{
	fmt.println("Error creating surface with SDL")
    }

    //caps : vk.SurfaceCapabilitiesKHR
    //vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(app.physical_device, app.surface, &caps)
    //fmt.println(caps.minImageCount, caps.maxImageCount, caps.currentExtent)
}


create_swapchain::proc(app : ^Application) {
    app.swapchain_image_extent.width = WINDOW_WIDTH
    app.swapchain_image_extent.height = WINDOW_HEIGHT 

    swapchain_create_info : vk.SwapchainCreateInfoKHR
    swapchain_create_info.sType = vk.StructureType.SWAPCHAIN_CREATE_INFO_KHR
    swapchain_create_info.surface = app.surface
    swapchain_create_info.minImageCount = 3
    swapchain_create_info.imageFormat = vk.Format.B8G8R8A8_SRGB
    swapchain_create_info.imageColorSpace = vk.ColorSpaceKHR.SRGB_NONLINEAR
    swapchain_create_info.imageExtent = app.swapchain_image_extent 
    swapchain_create_info.imageArrayLayers = 1 
    swapchain_create_info.imageUsage = {vk.ImageUsageFlag.COLOR_ATTACHMENT}
    swapchain_create_info.imageSharingMode = vk.SharingMode.EXCLUSIVE //una query para todas las queues 
    swapchain_create_info.preTransform = {vk.SurfaceTransformFlagKHR.IDENTITY}
    swapchain_create_info.compositeAlpha = {vk.CompositeAlphaFlagKHR.OPAQUE}
    swapchain_create_info.presentMode = vk.PresentModeKHR.FIFO
    swapchain_create_info.clipped = true
    swapchain_create_info.oldSwapchain = {}
    swap_res : vk.Result = vk.CreateSwapchainKHR(app.device, &swapchain_create_info, nil, &app.swapchain)
    if swap_res != vk.Result.SUCCESS{
	fmt.println("Error creating Swapchain")
	fmt.println(swap_res)
	return
    }


    //create imageViews
    vk.GetSwapchainImagesKHR(app.device, app.swapchain, &app.image_count, nil)
    swapchain_images_arr := make([^]vk.Image, app.image_count)
    vk.GetSwapchainImagesKHR(app.device, app.swapchain, &app.image_count, swapchain_images_arr)
    app.swapchain_images = swapchain_images_arr

    app.swapchain_image_views = make([^]vk.ImageView, app.image_count)
    for i:u32=0; i < app.image_count; i += 1 {
	image_view_create_info : vk.ImageViewCreateInfo
	image_view_create_info.sType = vk.StructureType.IMAGE_VIEW_CREATE_INFO
	image_view_create_info.image = app.swapchain_images[i]
	image_view_create_info.viewType = vk.ImageViewType.D2
	image_view_create_info.format = vk.Format.B8G8R8A8_SRGB
	image_view_create_info.components.r = vk.ComponentSwizzle.IDENTITY
	image_view_create_info.components.g = vk.ComponentSwizzle.IDENTITY
	image_view_create_info.components.b = vk.ComponentSwizzle.IDENTITY
	image_view_create_info.components.a = vk.ComponentSwizzle.IDENTITY
	image_view_create_info.subresourceRange.aspectMask = {vk.ImageAspectFlag.COLOR}
	image_view_create_info.subresourceRange.baseMipLevel = 0
	image_view_create_info.subresourceRange.levelCount = 1
	image_view_create_info.subresourceRange.baseArrayLayer = 0
        image_view_create_info.subresourceRange.layerCount = 1
	img_view_res : vk.Result = vk.CreateImageView(app.device, &image_view_create_info, nil, &app.swapchain_image_views[i])

	if img_view_res != vk.Result.SUCCESS{
	    fmt.println(img_view_res)
	    fmt.println("Error creating image_view: ", i)
	}
    } 
}


create_pipeline::proc(app : ^Application, vertex_binding_descriptions : ^[N_VERTEX_BINDINGS]vk.VertexInputBindingDescription, vertex_attribute_descriptions : ^[N_VERTEX_ATTRIBUTES]vk.VertexInputAttributeDescription){
    //Read vertex files bytes and check alignment
    vertex_shd_bytes, vtx_file_err := os.read_entire_file_from_path(VERTEX_SHADER_PATH, context.allocator)
    if vtx_file_err != nil{
	fmt.println("Couldnt read vertx_shader_file on pipeline creatinon")
    }
    defer delete(vertex_shd_bytes, context.allocator)
    if uintptr(raw_data(vertex_shd_bytes)) % 4 != 0{
	fmt.println("vertex bytes are not aligned aligned in pipeline creation")
    }
    vtx_shader := mem.slice_data_cast([]u32, vertex_shd_bytes)

    frag_shd_bytes, frag_file_err := os.read_entire_file_from_path(FRAGMENT_SHADER_PATH, context.allocator)
    if frag_file_err != nil{
	fmt.println("Couldnt read fragment_shader_file on pipeline creatinon")
    }
    defer delete(frag_shd_bytes, context.allocator)
    if uintptr(raw_data(frag_shd_bytes)) % 4 != 0{
	fmt.println("fragment bytes are not aligned aligned in pipeline creation")
    }
    frag_shader := mem.slice_data_cast([]u32, frag_shd_bytes)

    

    //create shader modules and stages
    //modules seem like the data containers and stages the specific shader stages(vertex stage or fragment stage)
    vertex_shader_create_info : vk.ShaderModuleCreateInfo
    vertex_shader_create_info.sType = vk.StructureType.SHADER_MODULE_CREATE_INFO
    vertex_shader_create_info.codeSize = len(vertex_shd_bytes) 
    vertex_shader_create_info.pCode = raw_data(vtx_shader)

    fragment_shader_create_info : vk.ShaderModuleCreateInfo
    fragment_shader_create_info.sType = vk.StructureType.SHADER_MODULE_CREATE_INFO
    fragment_shader_create_info.codeSize = len(frag_shd_bytes) 
    fragment_shader_create_info.pCode = raw_data(frag_shader)

    vertex_shader_module : vk.ShaderModule
    v_shader_mod_res := vk.CreateShaderModule(app.device, &vertex_shader_create_info, nil, &vertex_shader_module)
    if v_shader_mod_res != vk.Result.SUCCESS {
	fmt.println(v_shader_mod_res)
	fmt.println("Error creating vertex_shader_module")
    }

    fragment_shader_module : vk.ShaderModule
    f_shader_mod_res := vk.CreateShaderModule(app.device, &fragment_shader_create_info, nil, &fragment_shader_module)
    if f_shader_mod_res != vk.Result.SUCCESS {
	fmt.println(f_shader_mod_res)
	fmt.println("Error creating fragment_shader_module")
    }
    vertex_shader_stage_info : vk.PipelineShaderStageCreateInfo
    vertex_shader_stage_info.sType = vk.StructureType.PIPELINE_SHADER_STAGE_CREATE_INFO
    vertex_shader_stage_info.stage = {vk.ShaderStageFlag.VERTEX}
    vertex_shader_stage_info.module = vertex_shader_module
    vertex_shader_stage_info.pName = "main"

    fragment_shader_stage_info : vk.PipelineShaderStageCreateInfo
    fragment_shader_stage_info.sType = vk.StructureType.PIPELINE_SHADER_STAGE_CREATE_INFO
    fragment_shader_stage_info.stage = {vk.ShaderStageFlag.FRAGMENT}
    fragment_shader_stage_info.module = fragment_shader_module
    fragment_shader_stage_info.pName = "main"

    shader_stages :[]vk.PipelineShaderStageCreateInfo= {vertex_shader_stage_info, fragment_shader_stage_info}


    //vertex_input_stage (How to read vertices)
    //I crated the bindings and attributes beforehead in the main creation function
    vertex_input_state_info : vk.PipelineVertexInputStateCreateInfo
    vertex_input_state_info.sType = vk.StructureType.PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
    vertex_input_state_info.vertexBindingDescriptionCount = N_VERTEX_BINDINGS
    vertex_input_state_info.pVertexBindingDescriptions = raw_data(vertex_binding_descriptions)
    vertex_input_state_info.vertexAttributeDescriptionCount = N_VERTEX_ATTRIBUTES
    vertex_input_state_info.pVertexAttributeDescriptions = raw_data(vertex_attribute_descriptions)


    //input_assembly_stage (Hot to assemble triangles)
    input_assembly_state_info : vk.PipelineInputAssemblyStateCreateInfo
    input_assembly_state_info.sType = vk.StructureType.PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO
    input_assembly_state_info.topology = vk.PrimitiveTopology.TRIANGLE_LIST
    input_assembly_state_info.primitiveRestartEnable = false


    dynamic_states : [2]vk.DynamicState = {vk.DynamicState.VIEWPORT,vk.DynamicState.SCISSOR}
    dynamic_state_info : vk.PipelineDynamicStateCreateInfo
    dynamic_state_info.sType = vk.StructureType.PIPELINE_DYNAMIC_STATE_CREATE_INFO
    dynamic_state_info.dynamicStateCount = 2
    dynamic_state_info.pDynamicStates = raw_data(&dynamic_states)

    //viewport_state (where to draw)
    viewport_state_info : vk.PipelineViewportStateCreateInfo
    viewport_state_info.sType = vk.StructureType.PIPELINE_VIEWPORT_STATE_CREATE_INFO
    viewport_state_info.viewportCount = 1
    viewport_state_info.scissorCount = 1
    //viewport_state_info.pViewports = &viewport
    //viewport_state_info.pScissors = &scissor


    //rasterization_state (How to convert into pixels)
    rasterization_state_info : vk.PipelineRasterizationStateCreateInfo
    rasterization_state_info.sType = vk.StructureType.PIPELINE_RASTERIZATION_STATE_CREATE_INFO
    rasterization_state_info.depthClampEnable = false
    rasterization_state_info.rasterizerDiscardEnable = false
    rasterization_state_info.polygonMode = vk.PolygonMode.FILL
    rasterization_state_info.lineWidth = f32(1)
    rasterization_state_info.cullMode = {vk.CullModeFlag.BACK}
    rasterization_state_info.frontFace = vk.FrontFace.COUNTER_CLOCKWISE
    rasterization_state_info.depthBiasEnable = false
    rasterization_state_info.depthBiasConstantFactor = f32(0)
    rasterization_state_info.depthBiasClamp = f32(0)
    rasterization_state_info.depthBiasSlopeFactor = f32(0)


    //multisample_state (To perform anti-aliasing)
    multisample_state_info : vk.PipelineMultisampleStateCreateInfo
    multisample_state_info.sType = vk.StructureType.PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
    multisample_state_info.sampleShadingEnable = false
    multisample_state_info.rasterizationSamples = {vk.SampleCountFlag._1}


    //color_blend_state (How to combine color output)
    color_blend_attachment : vk.PipelineColorBlendAttachmentState
    color_blend_attachment.colorWriteMask = {vk.ColorComponentFlags.R,vk.ColorComponentFlags.B,
	vk.ColorComponentFlags.G,vk.ColorComponentFlags.A}
    color_blend_attachment.blendEnable = false  //transparencia?

    color_blend_state_info : vk.PipelineColorBlendStateCreateInfo
    color_blend_state_info.sType = vk.StructureType.PIPELINE_COLOR_BLEND_STATE_CREATE_INFO
    color_blend_state_info.logicOpEnable = false
    color_blend_state_info.logicOp = vk.LogicOp.COPY
    color_blend_state_info.attachmentCount = 1
    color_blend_state_info.pAttachments = &color_blend_attachment

    //depth_stencil
    depth_stencil_state_info : vk.PipelineDepthStencilStateCreateInfo
    depth_stencil_state_info.sType = vk.StructureType.PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO
    depth_stencil_state_info.depthTestEnable = true
    depth_stencil_state_info.depthWriteEnable = true
    depth_stencil_state_info.depthCompareOp = vk.CompareOp.LESS
    depth_stencil_state_info.depthBoundsTestEnable = false
    depth_stencil_state_info.minDepthBounds = f32(0)
    depth_stencil_state_info.maxDepthBounds = f32(1)
    depth_stencil_state_info.stencilTestEnable = false

    //pipeline_layout
    descriptor_set_layouts : [2]vk.DescriptorSetLayout = {app.frame_descriptor_set_layout, app.material_descriptor_set_layout}
    pipeline_layout_info : vk.PipelineLayoutCreateInfo
    pipeline_layout_info.sType = vk.StructureType.PIPELINE_LAYOUT_CREATE_INFO
    pipeline_layout_info.setLayoutCount = 2
    pipeline_layout_info.pSetLayouts = raw_data(&descriptor_set_layouts)
    pipeline_layout_info.pushConstantRangeCount = 0
    pipeline_layout_info.pPushConstantRanges = nil
    pipeline_layout_res := vk.CreatePipelineLayout(app.device, &pipeline_layout_info, nil,
	&app.graphics_pipeline_layout)
    if pipeline_layout_res != vk.Result.SUCCESS{
	fmt.println("Error creating graphics_pipeline_layout")
    }

    
    //info for Dynamic rendering
    attachment_formats : [1]vk.Format = {vk.Format.B8G8R8A8_SRGB}
    pipeline_dynamic_render_create : vk.PipelineRenderingCreateInfo
    pipeline_dynamic_render_create.sType = vk.StructureType.PIPELINE_RENDERING_CREATE_INFO
    pipeline_dynamic_render_create.pNext = nil
    pipeline_dynamic_render_create.colorAttachmentCount = 1
    pipeline_dynamic_render_create.pColorAttachmentFormats = raw_data(&attachment_formats)
    pipeline_dynamic_render_create.depthAttachmentFormat = app.depth_resources.format
    pipeline_dynamic_render_create.stencilAttachmentFormat = vk.Format.UNDEFINED

    //grapchis_pipeline
    pipeline_info : vk.GraphicsPipelineCreateInfo
    pipeline_info.sType = vk.StructureType.GRAPHICS_PIPELINE_CREATE_INFO
    pipeline_info.pNext = &pipeline_dynamic_render_create
    pipeline_info.pVertexInputState = &vertex_input_state_info
    pipeline_info.pInputAssemblyState = &input_assembly_state_info
    pipeline_info.pViewportState = &viewport_state_info
    pipeline_info.pRasterizationState = &rasterization_state_info
    pipeline_info.stageCount = 2
    pipeline_info.pStages = raw_data(shader_stages)
    pipeline_info.pMultisampleState = &multisample_state_info    
    pipeline_info.pColorBlendState = &color_blend_state_info
    pipeline_info.pDepthStencilState = &depth_stencil_state_info
    pipeline_info.pDynamicState = &dynamic_state_info
    pipeline_info.layout = app.graphics_pipeline_layout
    //pipeline_info.renderPass = app.render_pass //STATIC
    pipeline_info.renderPass = {}
    pipeline_info.subpass = 0

    graphic_pipeline_create_res := vk.CreateGraphicsPipelines(app.device, vk.PipelineCache{},
	1, &pipeline_info, nil, &app.graphics_pipeline)

    if graphic_pipeline_create_res != vk.Result.SUCCESS{
	fmt.println("Error creating graphics_pipeline")
    }

    vk.DestroyShaderModule(app.device, vertex_shader_module, nil)
    vk.DestroyShaderModule(app.device, fragment_shader_module, nil)
}


create_main_command_pool::proc(app : ^Application){
    command_pool_info : vk.CommandPoolCreateInfo
    command_pool_info.sType = vk.StructureType.COMMAND_POOL_CREATE_INFO
    command_pool_info.queueFamilyIndex = app.graphics_queue_family_index
    command_pool_info.flags = {vk.CommandPoolCreateFlag.RESET_COMMAND_BUFFER}

    res := vk.CreateCommandPool(app.device, &command_pool_info, nil, &app.main_command_pool)
    if res != vk.Result.SUCCESS {
	fmt.println("Error while creating command_pool")
    }
}


create_draw_command_buffers::proc(app : ^Application){
    command_buffer_allocate_info : vk.CommandBufferAllocateInfo
    command_buffer_allocate_info.sType = vk.StructureType.COMMAND_BUFFER_ALLOCATE_INFO
    command_buffer_allocate_info.commandPool = app.main_command_pool
    command_buffer_allocate_info.level = vk.CommandBufferLevel.PRIMARY
    command_buffer_allocate_info.commandBufferCount = app.image_count

    cbfs := make([^]vk.CommandBuffer, app.image_count)
    app.draw_command_buffers = cbfs
    res := vk.AllocateCommandBuffers(app.device, &command_buffer_allocate_info, app.draw_command_buffers)
    if res != vk.Result.SUCCESS {
	fmt.println("Error creating/allocating [^]draw_command_buffers")
    }
}


create_vertex_buffer::proc(app : ^Application){
    vertices : [N_VERTICES]Vertex
    setup_vertices(&vertices)
   
    staging_buffer : vk.Buffer
    staging_buffer_memory : vk.DeviceMemory
    staging_buffer_create_info : vk.BufferCreateInfo
    staging_buffer_create_info.sType = vk.StructureType.BUFFER_CREATE_INFO
    staging_buffer_create_info.size = size_of(Vertex) * N_VERTICES
    staging_buffer_create_info.usage = {vk.BufferUsageFlag.TRANSFER_SRC}
    staging_buffer_create_info.sharingMode = vk.SharingMode.EXCLUSIVE
    sb_property_flags : vk.MemoryPropertyFlags
    sb_property_flags = {vk.MemoryPropertyFlag.HOST_VISIBLE,vk.MemoryPropertyFlag.HOST_COHERENT}
    create_vk_buffer(app, &staging_buffer, &staging_buffer_create_info, &staging_buffer_memory, sb_property_flags)

    vertex_buffer_create_info : vk.BufferCreateInfo
    vertex_buffer_create_info.sType = vk.StructureType.BUFFER_CREATE_INFO
    vertex_buffer_create_info.size = size_of(Vertex) * N_VERTICES
    vertex_buffer_create_info.usage = {vk.BufferUsageFlag.VERTEX_BUFFER, vk.BufferUsageFlag.TRANSFER_DST}
    vertex_buffer_create_info.sharingMode = vk.SharingMode.EXCLUSIVE
    vb_property_flags : vk.MemoryPropertyFlags
    vb_property_flags = {vk.MemoryPropertyFlag.DEVICE_LOCAL}
    create_vk_buffer(app, &app.vertex_buffer, &vertex_buffer_create_info, &app.vertex_buffer_memory, vb_property_flags)

    data : rawptr
    vk.MapMemory(app.device, staging_buffer_memory, 0, staging_buffer_create_info.size, {}, &data)
    intrinsics.mem_copy(data, raw_data(&vertices), size_of(vertices)) //mem_copy(destiny, source, len)
    vk.UnmapMemory(app.device, staging_buffer_memory)
    
    copy_buffer(app, staging_buffer, app.vertex_buffer, size_of(vertices))
    vk.DestroyBuffer(app.device, staging_buffer, nil)
    vk.FreeMemory(app.device, staging_buffer_memory, nil)
}


create_index_buffer::proc(app : ^Application){
    indices : [N_INDICES]u16 = {u16(0),u16(1),u16(2),u16(2),u16(3),u16(0),
				u16(4),u16(5),u16(6),u16(6),u16(7),u16(4)}
   
    staging_buffer : vk.Buffer
    staging_buffer_memory : vk.DeviceMemory
    staging_buffer_create_info : vk.BufferCreateInfo
    staging_buffer_create_info.sType = vk.StructureType.BUFFER_CREATE_INFO
    staging_buffer_create_info.size = size_of(indices)
    staging_buffer_create_info.usage = {vk.BufferUsageFlag.TRANSFER_SRC}
    staging_buffer_create_info.sharingMode = vk.SharingMode.EXCLUSIVE
    sb_property_flags : vk.MemoryPropertyFlags
    sb_property_flags = {vk.MemoryPropertyFlag.HOST_VISIBLE,vk.MemoryPropertyFlag.HOST_COHERENT}
    create_vk_buffer(app, &staging_buffer, &staging_buffer_create_info, &staging_buffer_memory, sb_property_flags)

    index_buffer_create_info : vk.BufferCreateInfo
    index_buffer_create_info.sType = vk.StructureType.BUFFER_CREATE_INFO
    index_buffer_create_info.size = size_of(indices)
    index_buffer_create_info.usage = {vk.BufferUsageFlag.INDEX_BUFFER,vk.BufferUsageFlag.TRANSFER_DST}
    index_buffer_create_info.sharingMode = vk.SharingMode.EXCLUSIVE
    ib_property_flags : vk.MemoryPropertyFlags
    ib_property_flags = {vk.MemoryPropertyFlag.DEVICE_LOCAL}
    create_vk_buffer(app, &app.index_buffer, &index_buffer_create_info, &app.index_buffer_memory, ib_property_flags)

    data : rawptr
    vk.MapMemory(app.device, staging_buffer_memory, 0, staging_buffer_create_info.size, {}, &data)
    intrinsics.mem_copy(data, raw_data(&indices), size_of(indices)) //mem_copy(destiny, source, len)
    vk.UnmapMemory(app.device, staging_buffer_memory)
    
    copy_buffer(app, staging_buffer, app.index_buffer, size_of(indices))
    vk.DestroyBuffer(app.device, staging_buffer, nil)
    vk.FreeMemory(app.device, staging_buffer_memory, nil)
}


create_sync_objects::proc(app : ^Application){
    semaphore_info : vk.SemaphoreCreateInfo
    semaphore_info.sType = vk.StructureType.SEMAPHORE_CREATE_INFO

    fence_info : vk.FenceCreateInfo
    fence_info.sType = vk.StructureType.FENCE_CREATE_INFO
    fence_info.flags = {vk.FenceCreateFlag.SIGNALED}

    if vk.CreateSemaphore(app.device, &semaphore_info, nil, &app.image_available_semaphore) != vk.Result.SUCCESS{
	fmt.println("Error creating image_available_semaphore")
    }
    if vk.CreateSemaphore(app.device, &semaphore_info, nil, &app.render_finished_semaphore) != vk.Result.SUCCESS{
	fmt.println("Error creating render_finished_semaphore")
    }
    if vk.CreateFence(app.device, &fence_info, nil, &app.in_flight_fence) != vk.Result.SUCCESS{
	fmt.println("Error creating in_flight_fence")
    }
}


create_test_texture::proc(app : ^Application){
    //1. Load image from file
    img0, err := png.load_from_file("images/texture1.png")
    if err != nil {
        fmt.eprintf("Failed to load image: %v\n", err)
        return
    }
    
    img0_size :vk.DeviceSize= vk.DeviceSize(img0.width * img0.height * img0.channels)

    defer png.destroy(img0)
    /*
    fmt.printf("Loaded image dimensions: %d x %d\n", img0.width, img0.height)
    fmt.printf("Channels: %d\n", img0.channels)
    fmt.printf("size : %d\n", u32(img0_size))
    */
    //3. Allocate memory for texture
    t0_staging_buffer : vk.Buffer
    t0_staging_buffer_memory : vk.DeviceMemory
    t0_staging_buffer_create_info : vk.BufferCreateInfo
    t0_staging_buffer_create_info.sType = vk.StructureType.BUFFER_CREATE_INFO
    t0_staging_buffer_create_info.size = img0_size
    t0_staging_buffer_create_info.usage = {vk.BufferUsageFlag.TRANSFER_SRC}
    t0_staging_buffer_create_info.sharingMode = vk.SharingMode.EXCLUSIVE
    t0_sb_property_flags : vk.MemoryPropertyFlags
    t0_sb_property_flags = {vk.MemoryPropertyFlag.HOST_VISIBLE,vk.MemoryPropertyFlag.HOST_COHERENT}
    create_vk_buffer(app, &t0_staging_buffer, &t0_staging_buffer_create_info, &t0_staging_buffer_memory, t0_sb_property_flags)

    
    data_img0 : rawptr
    vk.MapMemory(app.device, t0_staging_buffer_memory,0,img0_size,{},&data_img0)
    intrinsics.mem_copy(data_img0, &img0.pixels.buf[0], img0_size)
    vk.UnmapMemory(app.device, t0_staging_buffer_memory)

    create_image(app, &app.textures[0].t_image, &app.textures[0].t_memory,
	{vk.MemoryPropertyFlag.DEVICE_LOCAL},vk.Format.R8G8B8A8_SRGB, u32(img0.width),
	u32(img0.height),{vk.ImageUsageFlags.TRANSFER_DST,vk.ImageUsageFlags.SAMPLED}, vk.ImageTiling.OPTIMAL)


    //5. Upload image pixels to texture object (using a barrer to transition the layout)
    transition_image_layout(app, app.textures[0].t_image, vk.Format.R8G8B8A8_SRGB, vk.ImageLayout.UNDEFINED,
	vk.ImageLayout.TRANSFER_DST_OPTIMAL)

    copy_buffer_to_image(app, t0_staging_buffer, app.textures[0].t_image, u32(img0.width), u32(img0.height))

    transition_image_layout(app, app.textures[0].t_image, vk.Format.R8G8B8A8_SRGB,
	vk.ImageLayout.TRANSFER_DST_OPTIMAL, vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL)
    
    vk.DestroyBuffer(app.device, t0_staging_buffer, nil)
    vk.FreeMemory(app.device, t0_staging_buffer_memory, nil)
    //6. Create image view
    create_image_view(app, &app.textures[0].t_image_view, app.textures[0].t_image,vk.Format.R8G8B8A8_SRGB,{vk.ImageAspectFlag.COLOR}) 

    //7. Create sampler obj
    sampler_info : vk.SamplerCreateInfo
    sampler_info.sType = vk.StructureType.SAMPLER_CREATE_INFO
    sampler_info.magFilter = vk.Filter.LINEAR
    sampler_info.minFilter = vk.Filter.LINEAR
    sampler_info.addressModeU = vk.SamplerAddressMode.CLAMP_TO_BORDER
    sampler_info.addressModeV = vk.SamplerAddressMode.REPEAT
    sampler_info.addressModeW = vk.SamplerAddressMode.REPEAT
    sampler_info.anisotropyEnable = false
    sampler_info.maxAnisotropy = f32(1)
    sampler_info.borderColor = vk.BorderColor.INT_OPAQUE_BLACK
    sampler_info.unnormalizedCoordinates = false
    sampler_info.compareEnable = false
    sampler_info.compareOp = vk.CompareOp.ALWAYS
    sampler_info.mipmapMode = vk.SamplerMipmapMode.LINEAR
    sampler_info.mipLodBias = f32(0)
    sampler_info.minLod = f32(0)
    sampler_info.maxLod = f32(0)

    if vk.CreateSampler(app.device, &sampler_info, nil, &app.textures[0].t_sampler) != vk.Result.SUCCESS {
	fmt.println("Failed to create sampler for image 0")
	return
    }
}

create_test_texture2::proc(app : ^Application){
    //1. Load image from file
    force_alpha_option :jpeg.Options= jpeg.Options{.alpha_add_if_missing}
    img0, err := jpeg.load_from_file("images/texture2.jpg", force_alpha_option)
    if err != nil {
        fmt.eprintf("Failed to load image: %v\n", err)
        return
    }
    
    img0_size :vk.DeviceSize= vk.DeviceSize(img0.width * img0.height * img0.channels)

    defer jpeg.destroy(img0)
    /*
    fmt.printf("Loaded image dimensions: %d x %d\n", img0.width, img0.height)
    fmt.printf("Channels: %d\n", img0.channels)
    fmt.printf("size : %d\n", u32(img0_size))
    */
    //3. Allocate memory for texture
    t0_staging_buffer : vk.Buffer
    t0_staging_buffer_memory : vk.DeviceMemory
    t0_staging_buffer_create_info : vk.BufferCreateInfo
    t0_staging_buffer_create_info.sType = vk.StructureType.BUFFER_CREATE_INFO
    t0_staging_buffer_create_info.size = img0_size
    t0_staging_buffer_create_info.usage = {vk.BufferUsageFlag.TRANSFER_SRC}
    t0_staging_buffer_create_info.sharingMode = vk.SharingMode.EXCLUSIVE
    t0_sb_property_flags : vk.MemoryPropertyFlags
    t0_sb_property_flags = {vk.MemoryPropertyFlag.HOST_VISIBLE,vk.MemoryPropertyFlag.HOST_COHERENT}
    create_vk_buffer(app, &t0_staging_buffer, &t0_staging_buffer_create_info, &t0_staging_buffer_memory, t0_sb_property_flags)

    
    data_img0 : rawptr
    vk.MapMemory(app.device, t0_staging_buffer_memory,0,img0_size,{},&data_img0)
    intrinsics.mem_copy(data_img0, &img0.pixels.buf[0], img0_size)
    vk.UnmapMemory(app.device, t0_staging_buffer_memory)

    create_image(app, &app.textures[1].t_image, &app.textures[1].t_memory,
	{vk.MemoryPropertyFlag.DEVICE_LOCAL},vk.Format.R8G8B8A8_SRGB, u32(img0.width),
	u32(img0.height),{vk.ImageUsageFlags.TRANSFER_DST,vk.ImageUsageFlags.SAMPLED}, vk.ImageTiling.OPTIMAL)

    //5. Upload image pixels to texture object (using a barrer to transition the layout)
    transition_image_layout(app, app.textures[1].t_image, vk.Format.R8G8B8A8_SRGB, vk.ImageLayout.UNDEFINED,
	vk.ImageLayout.TRANSFER_DST_OPTIMAL)

    copy_buffer_to_image(app, t0_staging_buffer, app.textures[1].t_image, u32(img0.width), u32(img0.height))

    transition_image_layout(app, app.textures[1].t_image, vk.Format.R8G8B8A8_SRGB,
	vk.ImageLayout.TRANSFER_DST_OPTIMAL, vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL)
    
    vk.DestroyBuffer(app.device, t0_staging_buffer, nil)
    vk.FreeMemory(app.device, t0_staging_buffer_memory, nil)
    //6. Create image view
    create_image_view(app, &app.textures[1].t_image_view, app.textures[1].t_image,vk.Format.R8G8B8A8_SRGB,{vk.ImageAspectFlag.COLOR}) 
    //7. Create sampler obj
    sampler_info : vk.SamplerCreateInfo
    sampler_info.sType = vk.StructureType.SAMPLER_CREATE_INFO
    sampler_info.magFilter = vk.Filter.LINEAR
    sampler_info.minFilter = vk.Filter.LINEAR
    sampler_info.addressModeU = vk.SamplerAddressMode.REPEAT
    sampler_info.addressModeV = vk.SamplerAddressMode.REPEAT
    sampler_info.addressModeW = vk.SamplerAddressMode.REPEAT
    sampler_info.anisotropyEnable = false
    sampler_info.maxAnisotropy = f32(1)
    sampler_info.borderColor = vk.BorderColor.INT_OPAQUE_BLACK
    sampler_info.unnormalizedCoordinates = false
    sampler_info.compareEnable = false
    sampler_info.compareOp = vk.CompareOp.ALWAYS
    sampler_info.minLod = f32(0)
    sampler_info.maxLod = f32(0)

    if vk.CreateSampler(app.device, &sampler_info, nil, &app.textures[1].t_sampler) != vk.Result.SUCCESS {
	fmt.println("Failed to create sampler for image 1")
	return
    }
}

create_depth_resources::proc(app : ^Application){
    depth_format := find_supported_format(app, {vk.Format.D32_SFLOAT_S8_UINT, vk.Format.D32_SFLOAT,
	vk.Format.D24_UNORM_S8_UINT}, vk.ImageTiling.OPTIMAL, {vk.FormatFeatureFlag.DEPTH_STENCIL_ATTACHMENT})
    if depth_format == {}{
	fmt.println("Error finding depth supported_format")
    } else {
	app.depth_resources.format = depth_format
    }

    

    create_image(app, &app.depth_resources.image, &app.depth_resources.memory,
	{vk.MemoryPropertyFlag.DEVICE_LOCAL},app.depth_resources.format, app.swapchain_image_extent.width,
	app.swapchain_image_extent.height,{vk.ImageUsageFlag.DEPTH_STENCIL_ATTACHMENT}, vk.ImageTiling.OPTIMAL)

    create_image_view(app, &app.depth_resources.image_view, app.depth_resources.image,app.depth_resources.format,{vk.ImageAspectFlag.DEPTH}) 

    transition_image_layout(app, app.depth_resources.image, app.depth_resources.format,
	vk.ImageLayout.UNDEFINED, vk.ImageLayout.DEPTH_STENCIL_ATTACHMENT_OPTIMAL)
    
}

//AUXS
create_image::proc(app :^Application, image : ^vk.Image, image_memory: ^vk.DeviceMemory,
    mem_property_flags : vk.MemoryPropertyFlags, format : vk.Format, width : u32, height :u32,
    usage_flags :vk.ImageUsageFlags, tiling: vk.ImageTiling){
    image_create_info : vk.ImageCreateInfo
    image_create_info.sType = vk.StructureType.IMAGE_CREATE_INFO
    image_create_info.imageType = vk.ImageType.D2
    image_create_info.extent.width = width 
    image_create_info.extent.height = height
    image_create_info.extent.depth = 1
    image_create_info.mipLevels = 1
    image_create_info.arrayLayers = 1
    image_create_info.format =  format
    image_create_info.tiling = tiling
    image_create_info.initialLayout = vk.ImageLayout.UNDEFINED
    image_create_info.usage = usage_flags
    image_create_info.sharingMode = vk.SharingMode.EXCLUSIVE
    image_create_info.samples = {vk.SampleCountFlags._1}
    image_create_info.flags = {}

    vk.CreateImage(app.device, &image_create_info ,nil ,image)   
    
    mem_requirements : vk.MemoryRequirements
    vk.GetImageMemoryRequirements(app.device, image^, &mem_requirements)

    physical_memory_properties : vk.PhysicalDeviceMemoryProperties
    vk.GetPhysicalDeviceMemoryProperties(app.physical_device, &physical_memory_properties)
    memory_type_index : u32 = 0
    for i : u32 = 0; i < physical_memory_properties.memoryTypeCount; i+= 1 {
	if (mem_requirements.memoryTypeBits & (1 << i)) != 0 && 
    (physical_memory_properties.memoryTypes[i].propertyFlags & mem_property_flags) == mem_property_flags {

	    memory_type_index = i
	    break
	}
    }   

    alloc_info : vk.MemoryAllocateInfo
    alloc_info.sType = vk.StructureType.MEMORY_ALLOCATE_INFO
    alloc_info.allocationSize = mem_requirements.size
    alloc_info.memoryTypeIndex = memory_type_index

    if vk.AllocateMemory(app.device, &alloc_info, nil, image_memory) != vk.Result.SUCCESS {
	fmt.println("Error allocating memory for texture 0")
	return
    }

    vk.BindImageMemory(app.device, image^, image_memory^, 0)

}


create_image_view::proc(app :^Application, image_view: ^vk.ImageView, image : vk.Image, format : vk.Format, aspect_flags : vk.ImageAspectFlags){
    img_view_create_info : vk.ImageViewCreateInfo
    img_view_create_info.sType = vk.StructureType.IMAGE_VIEW_CREATE_INFO
    img_view_create_info.image = image 
    img_view_create_info.viewType = vk.ImageViewType.D2
    img_view_create_info.format = format
    img_view_create_info.subresourceRange.aspectMask = aspect_flags
    img_view_create_info.subresourceRange.baseMipLevel = 0
    img_view_create_info.subresourceRange.levelCount = 1
    img_view_create_info.subresourceRange.baseArrayLayer = 0
    img_view_create_info.subresourceRange.layerCount = 1

    if vk.CreateImageView(app.device,&img_view_create_info, nil, image_view) != vk.Result.SUCCESS {
	fmt.println("Error creating img_view for img0")
    }
}


find_supported_format::proc(app: ^Application, candidates : []vk.Format, tiling : vk.ImageTiling, features : vk.FormatFeatureFlags) -> vk.Format{
    for format in candidates {
	properties : vk.FormatProperties
	vk.GetPhysicalDeviceFormatProperties(app.physical_device,format,&properties)
	if (tiling == vk.ImageTiling.LINEAR && (properties.linearTilingFeatures & features) == features) {
	    return format;
	} else if (tiling == vk.ImageTiling.OPTIMAL && (properties.optimalTilingFeatures & features) == features) {
	    return format;
	}
    }
    return {}  
}


record_draw_command_buffer_dynamic::proc(app : ^Application, command_buffer : vk.CommandBuffer, image_index : u32){
    comm_buff_begin_info : vk.CommandBufferBeginInfo
    comm_buff_begin_info.sType = vk.StructureType.COMMAND_BUFFER_BEGIN_INFO
    comm_buff_begin_info.flags = {vk.CommandBufferUsageFlag.ONE_TIME_SUBMIT}
    comm_buff_begin_info.pInheritanceInfo = nil

    if vk.BeginCommandBuffer(command_buffer, &comm_buff_begin_info) != vk.Result.SUCCESS {
	fmt.println("Error when begining command_buffer_record")
    }
   
    transition_image_layout(app, app.swapchain_images[image_index], vk.Format.R8G8B8A8_SRGB,
	vk.ImageLayout.UNDEFINED, vk.ImageLayout.COLOR_ATTACHMENT_OPTIMAL)
    clear_value: vk.ClearValue = {color = {float32 = {0, 0, 0, 1}}}

    color_attachment : vk.RenderingAttachmentInfo
    color_attachment.sType = vk.StructureType.RENDERING_ATTACHMENT_INFO
    color_attachment.imageView = app.swapchain_image_views[image_index]
    color_attachment.imageLayout = vk.ImageLayout.COLOR_ATTACHMENT_OPTIMAL
    color_attachment.loadOp = vk.AttachmentLoadOp.CLEAR
    color_attachment.storeOp = vk.AttachmentStoreOp.STORE
    color_attachment.clearValue = clear_value 

    depth_attachment : vk.RenderingAttachmentInfo
    depth_attachment.sType = vk.StructureType.RENDERING_ATTACHMENT_INFO
    depth_attachment.imageView = app.depth_resources.image_view
    depth_attachment.imageLayout = vk.ImageLayout.DEPTH_STENCIL_ATTACHMENT_OPTIMAL
    depth_attachment.loadOp = vk.AttachmentLoadOp.CLEAR
    depth_attachment.storeOp = vk.AttachmentStoreOp.DONT_CARE
    depth_attachment.clearValue.depthStencil = {depth = 1.0, stencil = 0}

    color_attachments : [1]vk.RenderingAttachmentInfo = {color_attachment}
    rendering_info : vk.RenderingInfo
    rendering_info.sType = vk.StructureType.RENDERING_INFO
    rendering_info.renderArea.offset = {0,0}
    rendering_info.renderArea.extent = app.swapchain_image_extent 
    rendering_info.layerCount = 1
    rendering_info.colorAttachmentCount = 1
    rendering_info.pColorAttachments = raw_data(&color_attachments)
    rendering_info.pDepthAttachment = &depth_attachment

    vk.CmdBeginRendering(command_buffer, &rendering_info)

    vk.CmdBindPipeline(command_buffer, vk.PipelineBindPoint.GRAPHICS, app.graphics_pipeline)

    vertex_buffers : [1]vk.Buffer = {app.vertex_buffer}
    offsets : [1]vk.DeviceSize = {0}
    vk.CmdBindVertexBuffers(command_buffer, 0, 1, raw_data(&vertex_buffers), raw_data(&offsets))

    vk.CmdBindIndexBuffer(command_buffer, app.index_buffer, 0, vk.IndexType.UINT16)

    viewport : vk.Viewport
    viewport.x = f32(0)
    viewport.y = f32(0)
    viewport.width = WINDOW_WIDTH
    viewport.height = WINDOW_HEIGHT
    viewport.minDepth = f32(0)
    viewport.maxDepth = f32(1)
    vk.CmdSetViewport(command_buffer, 0, 1, &viewport)

    scissor : vk.Rect2D
    scissor.offset.x = 0
    scissor.offset.y = 0
    scissor.extent = app.swapchain_image_extent 
    vk.CmdSetScissor(command_buffer, 0, 1, &scissor)


    sets_to_bind : [2]vk.DescriptorSet = {app.frame_descriptor_sets[0], app.material_descriptor_sets[0]}
    vk.CmdBindDescriptorSets(command_buffer, vk.PipelineBindPoint.GRAPHICS, app.graphics_pipeline_layout,
	0, 2, raw_data(&sets_to_bind), 0, nil)
    vk.CmdDrawIndexed(command_buffer, N_INDICES/2, 1, 0, 0, 0)

    texture1_bind : [1]vk.DescriptorSet = {app.material_descriptor_sets[1]}
    //cmdBindeDescSets() en los paramentros numericos, especifico primero desde donde y segundo la cantidad
    //entonces puedo reemplazar solo el de las texturas diciendo el indice=1 y cantidad=1
    vk.CmdBindDescriptorSets(command_buffer, vk.PipelineBindPoint.GRAPHICS, app.graphics_pipeline_layout,
	1, 1, raw_data(&texture1_bind), 0, nil)

    vk.CmdDrawIndexed(command_buffer, N_INDICES/2, 1, N_INDICES/2, 0, 0)

    vk.CmdEndRendering(command_buffer)
    transition_image_layout(app, app.swapchain_images[image_index], vk.Format.R8G8B8A8_SRGB,
	vk.ImageLayout.COLOR_ATTACHMENT_OPTIMAL, vk.ImageLayout.PRESENT_SRC_KHR)

    if vk.EndCommandBuffer(command_buffer) != vk.Result.SUCCESS {
	fmt.println("Error ending command_buffer_recording")
    }
}


create_vk_buffer::proc(app : ^Application, buffer_handle : ^vk.Buffer, buffer_info : ^vk.BufferCreateInfo,
    buffer_memory : ^vk.DeviceMemory, mem_property_flags : vk.MemoryPropertyFlags){
    buff_res := vk.CreateBuffer(app.device, buffer_info, nil, buffer_handle)
    if buff_res != vk.Result.SUCCESS {
	fmt.println("Error creating buffer with size", buffer_info.size)
	return
    }
   
    //buffer memory requirements expected
    mem_requirements : vk.MemoryRequirements
    vk.GetBufferMemoryRequirements(app.device, buffer_handle^, &mem_requirements)
    
    //find memory type index for the job
    physical_memory_properties : vk.PhysicalDeviceMemoryProperties
    vk.GetPhysicalDeviceMemoryProperties(app.physical_device, &physical_memory_properties)
    memory_type_index : u32 = 0
    for i : u32 = 0; i < physical_memory_properties.memoryTypeCount; i+= 1 {
	if (mem_requirements.memoryTypeBits & (1 << i)) != 0 && 
	    (physical_memory_properties.memoryTypes[i].propertyFlags & mem_property_flags) == mem_property_flags {

	    memory_type_index = i
	    break
	}
    }
    
    allocate_info : vk.MemoryAllocateInfo
    allocate_info.sType = vk.StructureType.MEMORY_ALLOCATE_INFO
    allocate_info.allocationSize = mem_requirements.size
    allocate_info.memoryTypeIndex = memory_type_index

    if vk.AllocateMemory(app.device, &allocate_info, nil, buffer_memory) != vk.Result.SUCCESS {
	fmt.println("Error allocating memory for buffer")
	return
    }
    vk.BindBufferMemory(app.device, buffer_handle^, buffer_memory^, 0)    
}


copy_buffer::proc(app : ^Application, src_buffer : vk.Buffer, dst_buffer : vk.Buffer, size : vk.DeviceSize){
    command_buffer : vk.CommandBuffer
    begin_single_time_command(app, &command_buffer)
    copy_region : vk.BufferCopy
    copy_region.srcOffset = 0
    copy_region.dstOffset = 0
    copy_region.size = size
    vk.CmdCopyBuffer(command_buffer, src_buffer, dst_buffer, 1, &copy_region)
    end_single_time_command(app, &command_buffer)
}


copy_buffer_to_image::proc(app : ^Application, src_buffer : vk.Buffer, dst_image : vk.Image, width:u32,height:u32){
    command_buffer : vk.CommandBuffer
    begin_single_time_command(app, &command_buffer)
    
    buffer_to_image_copy_info : vk.BufferImageCopy
    buffer_to_image_copy_info.bufferOffset = 0
    buffer_to_image_copy_info.bufferRowLength = 0
    buffer_to_image_copy_info.bufferImageHeight = 0
    buffer_to_image_copy_info.imageSubresource.aspectMask = {vk.ImageAspectFlags.COLOR}
    buffer_to_image_copy_info.imageSubresource.mipLevel = 0
    buffer_to_image_copy_info.imageSubresource.baseArrayLayer = 0
    buffer_to_image_copy_info.imageSubresource.layerCount = 1
    buffer_to_image_copy_info.imageOffset = {0,0,0}
    buffer_to_image_copy_info.imageExtent = {width, height, 1}

    vk.CmdCopyBufferToImage(command_buffer, src_buffer, dst_image, vk.ImageLayout.TRANSFER_DST_OPTIMAL,1,&buffer_to_image_copy_info)
    end_single_time_command(app, &command_buffer)
}


transition_image_layout::proc(app : ^Application, image : vk.Image, format : vk.Format, old_layout : vk.ImageLayout, new_layout : vk.ImageLayout){
    src_stage : vk.PipelineStageFlags
    dst_stage : vk.PipelineStageFlags
    has_stencil_component : bool = (format == vk.Format.D32_SFLOAT_S8_UINT || 
				    format == vk.Format.D24_UNORM_S8_UINT)
    

    single_time_command_buffer : vk.CommandBuffer
    begin_single_time_command(app, &single_time_command_buffer)
    barrier : vk.ImageMemoryBarrier
    barrier.sType = vk.StructureType.IMAGE_MEMORY_BARRIER
    barrier.oldLayout = old_layout
    barrier.newLayout = new_layout
    barrier.srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED
    barrier.dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED
    barrier.image = image
    barrier.subresourceRange.baseMipLevel = 0
    barrier.subresourceRange.levelCount = 1
    barrier.subresourceRange.baseArrayLayer = 0
    barrier.subresourceRange.layerCount = 1
    barrier.srcAccessMask = {}
    barrier.dstAccessMask = {}
    
    //modifiy barrier according color / depth
    if new_layout == vk.ImageLayout.DEPTH_STENCIL_ATTACHMENT_OPTIMAL {
	barrier.subresourceRange.aspectMask = {vk.ImageAspectFlags.DEPTH}
	if has_stencil_component {
	    barrier.subresourceRange.aspectMask |= {vk.ImageAspectFlags.STENCIL}
	}
    } else {
	barrier.subresourceRange.aspectMask = {vk.ImageAspectFlags.COLOR}
    }

    //
    if old_layout == vk.ImageLayout.UNDEFINED && new_layout == vk.ImageLayout.TRANSFER_DST_OPTIMAL {
	barrier.srcAccessMask = {}
	barrier.dstAccessMask = {vk.AccessFlags.TRANSFER_WRITE}
	src_stage = {vk.PipelineStageFlags.TOP_OF_PIPE}
	dst_stage = {vk.PipelineStageFlags.TRANSFER}

    } else if old_layout == vk.ImageLayout.UNDEFINED &&	new_layout == vk.ImageLayout.COLOR_ATTACHMENT_OPTIMAL{
	barrier.srcAccessMask = {}
	barrier.dstAccessMask = {vk.AccessFlags.COLOR_ATTACHMENT_WRITE}
	src_stage = {vk.PipelineStageFlags.TOP_OF_PIPE}
	dst_stage = {vk.PipelineStageFlags.COLOR_ATTACHMENT_OUTPUT}

    } else if old_layout == vk.ImageLayout.UNDEFINED &&	new_layout == vk.ImageLayout.DEPTH_STENCIL_ATTACHMENT_OPTIMAL{
	
	barrier.srcAccessMask = {}
	barrier.dstAccessMask = {vk.AccessFlags.DEPTH_STENCIL_ATTACHMENT_WRITE,vk.AccessFlags.DEPTH_STENCIL_ATTACHMENT_READ}
	src_stage = {vk.PipelineStageFlags.TOP_OF_PIPE}
	dst_stage = {vk.PipelineStageFlags.EARLY_FRAGMENT_TESTS}

    } else if old_layout == vk.ImageLayout.TRANSFER_DST_OPTIMAL &&
		new_layout == vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL{
	barrier.srcAccessMask = {vk.AccessFlags.TRANSFER_WRITE}
	barrier.dstAccessMask = {vk.AccessFlags.SHADER_READ}
	src_stage = {vk.PipelineStageFlags.TRANSFER}
	dst_stage = {vk.PipelineStageFlags.FRAGMENT_SHADER}

    } else if old_layout == vk.ImageLayout.COLOR_ATTACHMENT_OPTIMAL &&
		new_layout == vk.ImageLayout.PRESENT_SRC_KHR{
	barrier.srcAccessMask = {vk.AccessFlags.COLOR_ATTACHMENT_WRITE}
	barrier.dstAccessMask = {}
	src_stage = {vk.PipelineStageFlags.COLOR_ATTACHMENT_OUTPUT}
	dst_stage = {vk.PipelineStageFlags.BOTTOM_OF_PIPE}

    } else {
	fmt.println("Image layout transition not supported")
	return
    }

    vk.CmdPipelineBarrier(single_time_command_buffer, src_stage, dst_stage,
	{}, 0, nil, 0, nil, 1, &barrier)

    end_single_time_command(app, &single_time_command_buffer)
}


begin_single_time_command::proc(app : ^Application, command_buffer : ^vk.CommandBuffer){
    allocate_info : vk.CommandBufferAllocateInfo
    allocate_info.sType = vk.StructureType.COMMAND_BUFFER_ALLOCATE_INFO
    allocate_info.level = vk.CommandBufferLevel.PRIMARY
    allocate_info.commandPool = app.main_command_pool
    allocate_info.commandBufferCount = 1

    vk.AllocateCommandBuffers(app.device, &allocate_info, command_buffer)

    begin_info : vk.CommandBufferBeginInfo
    begin_info.sType = vk.StructureType.COMMAND_BUFFER_BEGIN_INFO
    begin_info.flags = {vk.CommandBufferUsageFlag.ONE_TIME_SUBMIT}

    vk.BeginCommandBuffer(command_buffer^, &begin_info)
}


end_single_time_command::proc(app: ^Application, command_buffer : ^vk.CommandBuffer){
    vk.EndCommandBuffer(command_buffer^)

    submit_info : vk.SubmitInfo
    submit_info.sType = vk.StructureType.SUBMIT_INFO
    submit_info.commandBufferCount = 1
    submit_info.pCommandBuffers = command_buffer

    vk.QueueSubmit(app.graphics_queue, 1, &submit_info, {})
    vk.QueueWaitIdle(app.graphics_queue)

    vk.FreeCommandBuffers(app.device, app.main_command_pool, 1, command_buffer)
}


setup_vertices::proc(vertices : ^[N_VERTICES]Vertex){
    vertices[0].pos = {f32(-0.5), f32(-0.5), f32(0.1)}
    vertices[0].color = {f32(1), f32(0), f32(0)}
    vertices[0].tex_coords = {f32(0), f32(0)}

    vertices[1].pos = {f32(-0.5), f32(0), f32(0.1)}
    vertices[1].color = {f32(1), f32(0), f32(0)}
    vertices[1].tex_coords = {f32(0), f32(1)}

    vertices[2].pos = {f32(0), f32(0), f32(0.1)}
    vertices[2].color = {f32(1), f32(0), f32(1)}
    vertices[2].tex_coords = {f32(1), f32(1)}

    vertices[3].pos = {f32(0), f32(-0.5), f32(0.1)}
    vertices[3].color = {f32(1), f32(0), f32(0)}
    vertices[3].tex_coords = {f32(1), f32(0)}


    vertices[4].pos = {f32(-0.1), f32(-0.1), f32(0.5)}
    vertices[4].color = {f32(0), f32(1), f32(0)}
    vertices[4].tex_coords = {f32(0), f32(0)}

    vertices[5].pos = {f32(-0.1), f32(0.4), f32(0.5)}
    vertices[5].color = {f32(0), f32(1), f32(0)}
    vertices[5].tex_coords = {f32(0), f32(1)}

    vertices[6].pos = {f32(0.4), f32(0.4), f32(0.5)}
    vertices[6].color = {f32(0), f32(1), f32(1)}
    vertices[6].tex_coords = {f32(1), f32(1)}

    vertices[7].pos = {f32(0.4), f32(-0.1), f32(0.5)}
    vertices[7].color = {f32(0), f32(1), f32(0)}
    vertices[7].tex_coords = {f32(1), f32(0)}
}
