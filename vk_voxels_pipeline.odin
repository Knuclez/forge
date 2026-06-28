package testsito

import "core:fmt"
import "core:os"
import "core:mem"
import "core:image/jpeg"
import "core:image/png"
import "base:intrinsics"
import "core:math/linalg/glsl"
import vk "vendor:vulkan"

VOXEL_VERTEX_SHADER_PATH :: "shaders/sh_compiled/voxel_vert.spv"
VOXEL_FRAGMENT_SHADER_PATH :: "shaders/sh_compiled/voxel_frag.spv"
N_VOXEL_VERTEX_BINDINGS :: 1
N_VOXEL_VERTEX_ATTRIBUTES :: 3
N_VOXEL_VERTICES :: 8
N_VOXEL_INDICES :: 36
MAX_VOXEL_TEXTURES :: 2

prepare_voxels_pipeline::proc(app : ^vkApplication){
    vertex_binding_descriptions : [N_VOXEL_VERTEX_BINDINGS]vk.VertexInputBindingDescription
    vertex_attribute_descriptions : [N_VOXEL_VERTEX_ATTRIBUTES]vk.VertexInputAttributeDescription
    prepare_vertex_binding_descriptions(&vertex_binding_descriptions)
    prepare_vertex_attribute_descriptions(&vertex_attribute_descriptions)
    create_test_texture(app)
    create_test_texture2(app)
    create_vertex_buffer(app)
    create_index_buffer(app)
    prepare_material_descriptor_set_layout(app)
    instantiate_material_descriptor_sets(app)
    create_voxels_pipeline(app, &vertex_binding_descriptions, &vertex_attribute_descriptions)
}


prepare_vertex_binding_descriptions::proc(vertex_binding_descriptions : ^[N_VOXEL_VERTEX_BINDINGS]vk.VertexInputBindingDescription){
    vertex_binding_descriptions[0].binding = 0;
    vertex_binding_descriptions[0].stride = u32(size_of(Vertex))
    vertex_binding_descriptions[0].inputRate = vk.VertexInputRate.VERTEX
}


prepare_vertex_attribute_descriptions::proc(vertex_attribute_descriptions : ^[N_VOXEL_VERTEX_ATTRIBUTES]vk.VertexInputAttributeDescription){
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

create_test_texture::proc(app : ^vkApplication){
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

create_test_texture2::proc(app : ^vkApplication){
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

create_vertex_buffer::proc(app : ^vkApplication){
    //vertices : [N_ENGINE_VOXELS*8]Vertex
    vertices : [N_VOXEL_VERTICES]Vertex
    setup_voxel_vertices(&vertices)
   
    staging_buffer : vk.Buffer
    staging_buffer_memory : vk.DeviceMemory
    staging_buffer_create_info : vk.BufferCreateInfo
    staging_buffer_create_info.sType = vk.StructureType.BUFFER_CREATE_INFO
    staging_buffer_create_info.size = size_of(vertices)
    staging_buffer_create_info.usage = {vk.BufferUsageFlag.TRANSFER_SRC}
    staging_buffer_create_info.sharingMode = vk.SharingMode.EXCLUSIVE
    sb_property_flags : vk.MemoryPropertyFlags
    sb_property_flags = {vk.MemoryPropertyFlag.HOST_VISIBLE,vk.MemoryPropertyFlag.HOST_COHERENT}
    create_vk_buffer(app, &staging_buffer, &staging_buffer_create_info, &staging_buffer_memory, sb_property_flags)

    vertex_buffer_create_info : vk.BufferCreateInfo
    vertex_buffer_create_info.sType = vk.StructureType.BUFFER_CREATE_INFO
    vertex_buffer_create_info.size = size_of(vertices)
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


setup_voxel_vertices::proc(vertices : ^[N_VOXEL_VERTICES]Vertex){
    vertices[0].pos = {f32(-0.5), f32(-0.5), f32(-0.5)}
    vertices[0].color = {f32(1), f32(0), f32(0)}
    vertices[0].tex_coords = {f32(0), f32(0)}

    vertices[1].pos = {f32(-0.5), f32(0.5), f32(-0.5)}
    vertices[1].color = {f32(1), f32(0), f32(0)}
    vertices[1].tex_coords = {f32(0), f32(1)}

    vertices[2].pos = {f32(0.5), f32(0.5), f32(-0.5)}
    vertices[2].color = {f32(1), f32(0), f32(1)}
    vertices[2].tex_coords = {f32(1), f32(1)}

    vertices[3].pos = {f32(0.5), f32(-0.5), f32(-0.5)}
    vertices[3].color = {f32(1), f32(0), f32(0)}
    vertices[3].tex_coords = {f32(1), f32(0)}

    vertices[4].pos = {f32(0.5), f32(0.5), f32(0.5)}
    vertices[4].color = {f32(0), f32(1), f32(0)}
    vertices[4].tex_coords = {f32(0), f32(0)}

    vertices[5].pos = {f32(0.5), f32(-0.5), f32(0.5)}
    vertices[5].color = {f32(0), f32(1), f32(0)}
    vertices[5].tex_coords = {f32(0), f32(1)}

    vertices[6].pos = {f32(-0.5), f32(0.5), f32(0.5)}
    vertices[6].color = {f32(0), f32(1), f32(1)}
    vertices[6].tex_coords = {f32(1), f32(1)}

    vertices[7].pos = {f32(-0.5), f32(-0.5), f32(0.5)}
    vertices[7].color = {f32(0), f32(1), f32(0)}
    vertices[7].tex_coords = {f32(1), f32(0)}
}


create_index_buffer::proc(app : ^vkApplication){
    indices : [N_VOXEL_INDICES]u16 = {u16(0),u16(1),u16(2),u16(2),u16(3),u16(0),
				u16(3),u16(2),u16(4),u16(4),u16(5),u16(3),
				u16(5),u16(4),u16(6),u16(6),u16(7),u16(5),
				u16(7),u16(6),u16(1),u16(1),u16(0),u16(7),
				u16(0),u16(3),u16(5),u16(5),u16(7),u16(0),
				u16(1),u16(6),u16(4),u16(4),u16(2),u16(1)}
   
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



prepare_material_descriptor_set_layout::proc(app : ^vkApplication){
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

instantiate_material_descriptor_sets::proc(app : ^vkApplication){
    descriptor_pool_sizes : [1]vk.DescriptorPoolSize
    descriptor_pool_sizes[0].type = vk.DescriptorType.COMBINED_IMAGE_SAMPLER
    descriptor_pool_sizes[0].descriptorCount = MAX_VOXEL_TEXTURES 

    descriptor_pool_create_info : vk.DescriptorPoolCreateInfo
    descriptor_pool_create_info.sType = vk.StructureType.DESCRIPTOR_POOL_CREATE_INFO
    descriptor_pool_create_info.poolSizeCount = 1
    descriptor_pool_create_info.pPoolSizes = raw_data(&descriptor_pool_sizes)
    descriptor_pool_create_info.maxSets = u32(MAX_VOXEL_TEXTURES)

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



create_voxels_pipeline::proc(app : ^vkApplication, vertex_binding_descriptions : ^[N_VOXEL_VERTEX_BINDINGS]vk.VertexInputBindingDescription, vertex_attribute_descriptions : ^[N_VOXEL_VERTEX_ATTRIBUTES]vk.VertexInputAttributeDescription){
    //Read vertex files bytes and check alignment
    vertex_shd_bytes, vtx_file_err := os.read_entire_file_from_path(VOXEL_VERTEX_SHADER_PATH, context.allocator)
    if vtx_file_err != nil{
	fmt.println("Couldnt read vertx_shader_file on pipeline creatinon")
    }
    defer delete(vertex_shd_bytes, context.allocator)
    if uintptr(raw_data(vertex_shd_bytes)) % 4 != 0{
	fmt.println("vertex bytes are not aligned aligned in pipeline creation")
    }
    vtx_shader := mem.slice_data_cast([]u32, vertex_shd_bytes)

    frag_shd_bytes, frag_file_err := os.read_entire_file_from_path(VOXEL_FRAGMENT_SHADER_PATH, context.allocator)
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
    vertex_input_state_info.vertexBindingDescriptionCount = N_VOXEL_VERTEX_BINDINGS
    vertex_input_state_info.pVertexBindingDescriptions = raw_data(vertex_binding_descriptions)
    vertex_input_state_info.vertexAttributeDescriptionCount = N_VOXEL_VERTEX_ATTRIBUTES
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


    //push_constatns
    push_constants_range : vk.PushConstantRange
    push_constants_range.stageFlags = {vk.ShaderStageFlag.VERTEX}
    push_constants_range.offset = 0
    push_constants_range.size = size_of(glsl.mat4)

    //pipeline_layout
    descriptor_set_layouts : [2]vk.DescriptorSetLayout = {app.frame_descriptor_set_layout, app.material_descriptor_set_layout}
    pipeline_layout_info : vk.PipelineLayoutCreateInfo
    pipeline_layout_info.sType = vk.StructureType.PIPELINE_LAYOUT_CREATE_INFO
    pipeline_layout_info.setLayoutCount = 2
    pipeline_layout_info.pSetLayouts = raw_data(&descriptor_set_layouts)
    pipeline_layout_info.pushConstantRangeCount = 1
    pipeline_layout_info.pPushConstantRanges = &push_constants_range 
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



