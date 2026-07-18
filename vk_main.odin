package testsito

import "core:fmt"
import "core:os"
import "core:mem"
import "core:time"
import "core:math/linalg/glsl"
import "vendor:sdl2"
import "base:runtime"
import "base:intrinsics"
import vk "vendor:vulkan"

WINDOW_WIDTH :: 1000
WINDOW_HEIGHT :: 800
MAX_FRAMES_IN_FLIGHT :: 1

draw_frame::proc(engine : ^Engine, app : ^vkApplication, current_time : f32){
    vk.WaitForFences(app.device, 1 , &app.in_flight_fence, true, max(u64))
    vk.ResetFences(app.device, 1, &app.in_flight_fence)

    image_index : u32
    ani_res := vk.AcquireNextImageKHR(app.device, app.swapchain, max(u64),app.image_available_semaphore, {}, &image_index)
    
    if ani_res == vk.Result.ERROR_OUT_OF_DATE_KHR || ani_res == vk.Result.SUBOPTIMAL_KHR {
	fmt.println("swapchain out of date, recreating...")
	recreate_swapchain(app)
	return
    }

    vk.ResetCommandBuffer(app.draw_command_buffers[image_index], {})
    record_draw_command_buffer_dynamic(engine, app, app.draw_command_buffers[image_index], image_index)

    update_global_transform_UBO(engine, app, current_time)
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

    present_error := vk.QueuePresentKHR(app.graphics_queue, &present_info)
    if present_error == vk.Result.ERROR_OUT_OF_DATE_KHR || present_error == vk.Result.SUBOPTIMAL_KHR || app.frame_buffer_resized{
	fmt.println("swapchain out of date after present, recreating...")
	recreate_swapchain(app)
	return
    }
}


resize_extent::proc(app : ^vkApplication){
    w,h : i32
    sdl2.Vulkan_GetDrawableSize(app.window, &w, &h)
    app.swapchain_image_extent.width = u32(w)
    app.swapchain_image_extent.height = u32(h)
}

record_draw_command_buffer_dynamic::proc(engine: ^Engine, app : ^vkApplication, command_buffer : vk.CommandBuffer, image_index : u32){
    comm_buff_begin_info : vk.CommandBufferBeginInfo
    comm_buff_begin_info.sType = vk.StructureType.COMMAND_BUFFER_BEGIN_INFO
    comm_buff_begin_info.flags = {vk.CommandBufferUsageFlag.ONE_TIME_SUBMIT}
    comm_buff_begin_info.pInheritanceInfo = nil

    if vk.BeginCommandBuffer(command_buffer, &comm_buff_begin_info) != vk.Result.SUCCESS {
	fmt.println("Error when begining command_buffer_record")
    }
   
    transition_image_layout(app, app.swapchain_images[image_index], vk.Format.B8G8R8A8_SRGB,
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

    viewport : vk.Viewport
    viewport.x = f32(0)
    viewport.y = f32(0)
    viewport.width = f32(app.swapchain_image_extent.width)
    viewport.height = f32(app.swapchain_image_extent.height)
    viewport.minDepth = f32(0)
    viewport.maxDepth = f32(1)
    vk.CmdSetViewport(command_buffer, 0, 1, &viewport)

    scissor : vk.Rect2D
    scissor.offset.x = 0
    scissor.offset.y = 0
    scissor.extent = app.swapchain_image_extent 
    vk.CmdSetScissor(command_buffer, 0, 1, &scissor)

    //NEW SHIT
    vk.CmdBindPipeline(command_buffer, vk.PipelineBindPoint.GRAPHICS, app.grid_gp)
    grid_vertex_buffers : [1]vk.Buffer = {app.grid_vertex_buffer}
    grid_vertex_offsets : [1]vk.DeviceSize = {0}
    vk.CmdBindVertexBuffers(command_buffer, 0, 1, raw_data(&grid_vertex_buffers), raw_data(&grid_vertex_offsets))
    vk.CmdBindIndexBuffer(command_buffer, app.grid_index_buffer, 0, vk.IndexType.UINT16)

    grid_desc_sets : [1]vk.DescriptorSet = {app.frame_descriptor_sets[0]}
    vk.CmdBindDescriptorSets(command_buffer, vk.PipelineBindPoint.GRAPHICS, app.grid_gp_layout,
	0, 1, raw_data(&grid_desc_sets), 0, nil)
    
    vk.CmdDrawIndexed(command_buffer, N_GRID_INDICES, 1, 0, 0, 0)


    vertex_buffers : [1]vk.Buffer = {app.vertex_buffer}
    offsets : [1]vk.DeviceSize = {0}
    vk.CmdBindPipeline(command_buffer, vk.PipelineBindPoint.GRAPHICS, app.graphics_pipeline)
    vk.CmdBindVertexBuffers(command_buffer, 0, 1, raw_data(&vertex_buffers), raw_data(&offsets))
    vk.CmdBindIndexBuffer(command_buffer, app.index_buffer, 0, vk.IndexType.UINT16)

    sets_to_bind : [2]vk.DescriptorSet = {app.frame_descriptor_sets[0], app.material_descriptor_sets[0]}
    vk.CmdBindDescriptorSets(command_buffer, vk.PipelineBindPoint.GRAPHICS, app.graphics_pipeline_layout,
	0, 2, raw_data(&sets_to_bind), 0, nil)

    for &voxel in engine.voxels{
	vk.CmdPushConstants(command_buffer, app.graphics_pipeline_layout, {vk.ShaderStageFlag.VERTEX}, 0, size_of(glsl.mat4), raw_data(&voxel.model))

	vk.CmdDrawIndexed(command_buffer, N_VOXEL_INDICES, 1, 0, 0, 0)
    }

    vk.CmdEndRendering(command_buffer)
    transition_image_layout(app, app.swapchain_images[image_index], vk.Format.B8G8R8A8_SRGB,
	vk.ImageLayout.COLOR_ATTACHMENT_OPTIMAL, vk.ImageLayout.PRESENT_SRC_KHR)

    if vk.EndCommandBuffer(command_buffer) != vk.Result.SUCCESS {
	fmt.println("Error ending command_buffer_recording")
    }
}


update_global_transform_UBO::proc(engine : ^Engine, app : ^vkApplication, current_time : f32){
    ubo : GlobalTransformUBO
    ubo.model = glsl.mat4(1.0)
    ubo.view = engine.view_transform.model
    ubo.proj = engine.projection_transform

    intrinsics.mem_copy(app.uniform_buffers_mapped[0], &ubo, size_of(ubo))
}


//=========== CREATIONS/INITIALIZATIONS/CLEAN UP ============================================
recreate_swapchain::proc(app : ^vkApplication){
    fmt.println("empieza recreacion")
    app.frame_buffer_resized = false
    vk.DeviceWaitIdle(app.device)

    //destruir draw command buffers
    if app.draw_command_buffers != nil {
        vk.FreeCommandBuffers(app.device, app.main_command_pool, app.swapchain_image_count, app.draw_command_buffers)
        app.draw_command_buffers = nil
    }

    //destruir image views de la swapchain
    for i : u32 = 0; i < app.swapchain_image_count; i += 1 {
        if app.swapchain_image_views[i] != {} {
            vk.DestroyImageView(app.device, app.swapchain_image_views[i], nil)
        }
    }
    free(app.swapchain_image_views)
    free(app.swapchain_images)

    //destruir swapchain
    vk.DestroySwapchainKHR(app.device, app.swapchain, nil)

    //destruir depth resources
    vk.DestroyImageView(app.device, app.depth_resources.image_view, nil)
    vk.DestroyImage(app.device, app.depth_resources.image, nil)
    vk.FreeMemory(app.device, app.depth_resources.memory, nil)

    // ====== RECREAR ======
    create_swapchain(app)
    create_draw_command_buffers(app)
    create_depth_resources(app)
    fmt.println("Terimna crea")
}

init_vulkan::proc(engine : ^Engine, app : ^vkApplication) {
    vk_get_proc_addr := sdl2.Vulkan_GetVkGetInstanceProcAddr()
    if vk_get_proc_addr == nil {
	fmt.println("Fallo al obtener vkGetInstanceProcAddr")
	return
    }
    vk.load_proc_addresses_global(vk_get_proc_addr)

    app.swapchain_image_extent.width = WINDOW_WIDTH
    app.swapchain_image_extent.height = WINDOW_HEIGHT 

    create_instance(app) 
    if app.is_debug_mode{
	create_debug_callback(app)
    }
    create_logical_device(app)
    create_surface(app)
    create_swapchain(app)
    create_main_command_pool(app)
    create_draw_command_buffers(app)
    create_depth_resources(app)
    create_global_transform_UBO(app)
    prepare_frame_descriptor_set_layout(app)
    instantiate_frame_descriptor_sets(app)
    prepare_grid_pipeline(app)
    prepare_voxels_pipeline(app)
    create_sync_objects(app)
}


clean_up_vulkan::proc(app : ^vkApplication){
    vk.DeviceWaitIdle(app.device)

    //command buffers
    if app.draw_command_buffers != nil {
        vk.FreeCommandBuffers(app.device, app.main_command_pool, app.swapchain_image_count, app.draw_command_buffers)
    }

    //sync objects
    vk.DestroySemaphore(app.device, app.render_finished_semaphore, nil)
    vk.DestroySemaphore(app.device, app.image_available_semaphore, nil)
    vk.DestroyFence(app.device, app.in_flight_fence, nil)

    //descriptor pools (libera los descriptor sets implicitamente)
    vk.DestroyDescriptorPool(app.device, app.frame_descriptor_pool, nil)
    vk.DestroyDescriptorPool(app.device, app.material_descriptor_pool, nil)

    //descriptor set layouts
    vk.DestroyDescriptorSetLayout(app.device, app.frame_descriptor_set_layout, nil)
    vk.DestroyDescriptorSetLayout(app.device, app.material_descriptor_set_layout, nil)

    //pipelines y layouts
    vk.DestroyPipeline(app.device, app.graphics_pipeline, nil)
    vk.DestroyPipelineLayout(app.device, app.graphics_pipeline_layout, nil)
    vk.DestroyPipeline(app.device, app.grid_gp, nil)
    vk.DestroyPipelineLayout(app.device, app.grid_gp_layout, nil)

    //uniform buffers
    for i := 0; i < len(app.uniform_buffers); i += 1 {
        vk.DestroyBuffer(app.device, app.uniform_buffers[i], nil)
        vk.FreeMemory(app.device, app.uniform_buffers_memory[i], nil)
    }

    //voxels: vertex/index buffers
    vk.DestroyBuffer(app.device, app.vertex_buffer, nil)
    vk.FreeMemory(app.device, app.vertex_buffer_memory, nil)
    vk.DestroyBuffer(app.device, app.index_buffer, nil)
    vk.FreeMemory(app.device, app.index_buffer_memory, nil)

    //grid: vertex/index buffers
    vk.DestroyBuffer(app.device, app.grid_vertex_buffer, nil)
    vk.FreeMemory(app.device, app.grid_vertex_buffer_memory, nil)
    vk.DestroyBuffer(app.device, app.grid_index_buffer, nil)
    vk.FreeMemory(app.device, app.grid_index_buffer_memory, nil)

    //textures (todas)
    for t := 0; t < len(app.textures); t += 1 {
        if app.textures[t].t_sampler != {} {
            vk.DestroySampler(app.device, app.textures[t].t_sampler, nil)
        }
        if app.textures[t].t_image_view != {} {
            vk.DestroyImageView(app.device, app.textures[t].t_image_view, nil)
        }
        if app.textures[t].t_image != {} {
            vk.DestroyImage(app.device, app.textures[t].t_image, nil)
        }
        if app.textures[t].t_memory != {} {
            vk.FreeMemory(app.device, app.textures[t].t_memory, nil)
        }
    }

    //depth resources
    vk.DestroyImageView(app.device, app.depth_resources.image_view, nil)
    vk.DestroyImage(app.device, app.depth_resources.image, nil)
    vk.FreeMemory(app.device, app.depth_resources.memory, nil)

    //command pool
    vk.DestroyCommandPool(app.device, app.main_command_pool, nil)

    //swapchain image views
    if app.swapchain_image_views != nil {
        for i : u32 = 0; i < app.swapchain_image_count; i += 1 {
            vk.DestroyImageView(app.device, app.swapchain_image_views[i], nil)
        }
        free(app.swapchain_image_views)
    }
    free(app.swapchain_images)

    //swapchain
    vk.DestroySwapchainKHR(app.device, app.swapchain, nil)

    //device, surface, instance
    vk.DestroyDevice(app.device, nil)
    vk.DestroySurfaceKHR(app.instance, app.surface, nil)
    vk.DestroyInstance(app.instance, nil)
}


create_instance:: proc(app : ^vkApplication) {
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

debug_callback::proc"cdecl"(message_severity:vk.DebugUtilsMessageSeverityFlagsEXT,message_type: vk.DebugUtilsMessageTypeFlagsEXT, call_bak_data: ^vk.DebugUtilsMessengerCallbackDataEXT, ptr: rawptr) -> b32{
    context = runtime.default_context()
    fmt.println("Debug callback: ", call_bak_data.pMessage)
    fmt.println("   Severity: ", message_severity)
    fmt.println("   Type: ", message_type)

    for i:u32=0; i < call_bak_data.objectCount; i+=1 {
	fmt.println(call_bak_data.pObjects[i].objectHandle)
    }
    return false
}

create_debug_callback::proc(app : ^vkApplication){
    messenger_create_info : vk.DebugUtilsMessengerCreateInfoEXT
    messenger_create_info.sType = vk.StructureType.DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT
    messenger_create_info.messageSeverity = {vk.DebugUtilsMessageSeverityFlagEXT.VERBOSE,
					    vk.DebugUtilsMessageSeverityFlagEXT.WARNING,
					    vk.DebugUtilsMessageSeverityFlagEXT.ERROR}
    messenger_create_info.messageType = {vk.DebugUtilsMessageTypeFlagEXT.GENERAL,
					vk.DebugUtilsMessageTypeFlagEXT.VALIDATION,
					vk.DebugUtilsMessageTypeFlagEXT.PERFORMANCE}
    messenger_create_info.pfnUserCallback = debug_callback
    //TO-DO
}


create_logical_device::proc(app : ^vkApplication) { 
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

    descriptor_indexing_features : vk.PhysicalDeviceDescriptorIndexingFeatures
    descriptor_indexing_features.sType = vk.StructureType.PHYSICAL_DEVICE_DESCRIPTOR_INDEXING_FEATURES

    dynamic_rendering_features : vk.PhysicalDeviceVulkan13Features
    dynamic_rendering_features.sType = vk.StructureType.PHYSICAL_DEVICE_VULKAN_1_3_FEATURES
    dynamic_rendering_features.dynamicRendering = true
    dynamic_rendering_features.pNext = &descriptor_indexing_features

    physical_device : vk.PhysicalDevice 
    device_features : vk.PhysicalDeviceFeatures2 
    device_features.sType = vk.StructureType.PHYSICAL_DEVICE_FEATURES_2
    device_features.pNext = &dynamic_rendering_features
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
    

    device_create_info : vk.DeviceCreateInfo
    device_create_info.sType = vk.StructureType.DEVICE_CREATE_INFO
    device_create_info.pNext = &device_features
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


create_surface::proc(app : ^vkApplication){
    sfc_res : sdl2.bool = sdl2.Vulkan_CreateSurface(app.window, app.instance, &app.surface)
    if sfc_res == false{
	fmt.println("Error creating surface with SDL")
    }

    //caps : vk.SurfaceCapabilitiesKHR
    //vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(app.physical_device, app.surface, &caps)
    //fmt.println(caps.minImageCount, caps.maxImageCount, caps.currentExtent)
}


choose_swapchain_image_extent::proc(app : ^vkApplication){
    capabilities : vk.SurfaceCapabilitiesKHR
    vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(app.physical_device, app.surface, &capabilities)

    if capabilities.currentExtent.width != max(u32) {
	app.swapchain_image_extent = capabilities.currentExtent
	return 
    }

    w, h: i32
    sdl2.Vulkan_GetDrawableSize(app.window, &w, &h)

    extent := vk.Extent2D{
        width  = u32(w),
        height = u32(h),
    }

    extent.width = clamp(
        extent.width,
        capabilities.minImageExtent.width,
        capabilities.maxImageExtent.width,
    )

    extent.height = clamp(
        extent.height,
        capabilities.minImageExtent.height,
        capabilities.maxImageExtent.height,
    )

    app.swapchain_image_extent = extent
}

create_swapchain::proc(app : ^vkApplication) {
    choose_swapchain_image_extent(app)

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
    vk.GetSwapchainImagesKHR(app.device, app.swapchain, &app.swapchain_image_count, nil)
    swapchain_images_arr := make([^]vk.Image, app.swapchain_image_count)
    vk.GetSwapchainImagesKHR(app.device, app.swapchain, &app.swapchain_image_count, swapchain_images_arr)
    app.swapchain_images = swapchain_images_arr

    app.swapchain_image_views = make([^]vk.ImageView, app.swapchain_image_count)
    for i:u32=0; i < app.swapchain_image_count; i += 1 {
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

create_main_command_pool::proc(app : ^vkApplication){
    command_pool_info : vk.CommandPoolCreateInfo
    command_pool_info.sType = vk.StructureType.COMMAND_POOL_CREATE_INFO
    command_pool_info.queueFamilyIndex = app.graphics_queue_family_index
    command_pool_info.flags = {vk.CommandPoolCreateFlag.RESET_COMMAND_BUFFER}

    res := vk.CreateCommandPool(app.device, &command_pool_info, nil, &app.main_command_pool)
    if res != vk.Result.SUCCESS {
	fmt.println("Error while creating command_pool")
    }
}


create_draw_command_buffers::proc(app : ^vkApplication){
    command_buffer_allocate_info : vk.CommandBufferAllocateInfo
    command_buffer_allocate_info.sType = vk.StructureType.COMMAND_BUFFER_ALLOCATE_INFO
    command_buffer_allocate_info.commandPool = app.main_command_pool
    command_buffer_allocate_info.level = vk.CommandBufferLevel.PRIMARY
    command_buffer_allocate_info.commandBufferCount = app.swapchain_image_count

    cbfs := make([^]vk.CommandBuffer, app.swapchain_image_count)
    app.draw_command_buffers = cbfs
    res := vk.AllocateCommandBuffers(app.device, &command_buffer_allocate_info, app.draw_command_buffers)
    if res != vk.Result.SUCCESS {
	fmt.println("Error creating/allocating [^]draw_command_buffers")
    }
}


create_depth_resources::proc(app : ^vkApplication){
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


prepare_frame_descriptor_set_layout::proc(app : ^vkApplication){
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


create_global_transform_UBO::proc(app : ^vkApplication){
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


instantiate_frame_descriptor_sets::proc(app : ^vkApplication){
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



create_sync_objects::proc(app : ^vkApplication){
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


//AUXS
create_image::proc(app :^vkApplication, image : ^vk.Image, image_memory: ^vk.DeviceMemory,
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


create_image_view::proc(app :^vkApplication, image_view: ^vk.ImageView, image : vk.Image, format : vk.Format, aspect_flags : vk.ImageAspectFlags){
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


find_supported_format::proc(app: ^vkApplication, candidates : []vk.Format, tiling : vk.ImageTiling, features : vk.FormatFeatureFlags) -> vk.Format{
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





create_vk_buffer::proc(app : ^vkApplication, buffer_handle : ^vk.Buffer, buffer_info : ^vk.BufferCreateInfo,
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


copy_buffer::proc(app : ^vkApplication, src_buffer : vk.Buffer, dst_buffer : vk.Buffer, size : vk.DeviceSize){
    command_buffer : vk.CommandBuffer
    begin_single_time_command(app, &command_buffer)
    copy_region : vk.BufferCopy
    copy_region.srcOffset = 0
    copy_region.dstOffset = 0
    copy_region.size = size
    vk.CmdCopyBuffer(command_buffer, src_buffer, dst_buffer, 1, &copy_region)
    end_single_time_command(app, &command_buffer)
}


copy_buffer_to_image::proc(app : ^vkApplication, src_buffer : vk.Buffer, dst_image : vk.Image, width:u32,height:u32){
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


transition_image_layout::proc(app : ^vkApplication, image : vk.Image, format : vk.Format, old_layout : vk.ImageLayout, new_layout : vk.ImageLayout){
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


begin_single_time_command::proc(app : ^vkApplication, command_buffer : ^vk.CommandBuffer){
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


end_single_time_command::proc(app: ^vkApplication, command_buffer : ^vk.CommandBuffer){
    vk.EndCommandBuffer(command_buffer^)

    submit_info : vk.SubmitInfo
    submit_info.sType = vk.StructureType.SUBMIT_INFO
    submit_info.commandBufferCount = 1
    submit_info.pCommandBuffers = command_buffer

    vk.QueueSubmit(app.graphics_queue, 1, &submit_info, {})
    vk.QueueWaitIdle(app.graphics_queue)

    vk.FreeCommandBuffers(app.device, app.main_command_pool, 1, command_buffer)
}



