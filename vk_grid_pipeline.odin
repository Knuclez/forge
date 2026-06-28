package testsito

import "core:fmt"
import "core:os"
import "core:mem"
import "core:image/jpeg"
import "core:image/png"
import "base:intrinsics"
import "core:math/linalg/glsl"
import vk "vendor:vulkan"

GRID_VERTEX_SHADER_PATH :: "shaders/sh_compiled/grid_vert.spv"
GRID_FRAGMENT_SHADER_PATH :: "shaders/sh_compiled/grid_frag.spv"
N_GRID_VERTEX_BINDINGS :: 1
N_GRID_VERTEX_ATTRIBUTES :: 1
N_GRID_VERTICES :: 4
N_GRID_INDICES :: 6

GridVertex :: glsl.vec3

prepare_grid_pipeline::proc(app : ^vkApplication){
    vertex_binding_descriptions : [N_GRID_VERTEX_BINDINGS]vk.VertexInputBindingDescription
    vertex_attribute_descriptions : [N_GRID_VERTEX_ATTRIBUTES]vk.VertexInputAttributeDescription
    prepare_grid_vertex_binding_descriptions(&vertex_binding_descriptions)
    prepare_grid_vertex_attribute_descriptions(&vertex_attribute_descriptions)
    create_grid_vertex_buffer(app)
    create_grid_index_buffer(app)
    create_grid_pipeline(app, &vertex_binding_descriptions, &vertex_attribute_descriptions)
}


prepare_grid_vertex_binding_descriptions::proc(vertex_binding_descriptions : ^[N_GRID_VERTEX_BINDINGS]vk.VertexInputBindingDescription){
    vertex_binding_descriptions[0].binding = 0;
    vertex_binding_descriptions[0].stride = u32(size_of(GridVertex))
    vertex_binding_descriptions[0].inputRate = vk.VertexInputRate.VERTEX
}


prepare_grid_vertex_attribute_descriptions::proc(vertex_attribute_descriptions : ^[N_GRID_VERTEX_ATTRIBUTES]vk.VertexInputAttributeDescription){
    vertex_attribute_descriptions[0].binding = 0
    vertex_attribute_descriptions[0].location = 0
    vertex_attribute_descriptions[0].format = vk.Format.R32G32B32_SFLOAT
    vertex_attribute_descriptions[0].offset = u32(0)
}


create_grid_vertex_buffer::proc(app : ^vkApplication){
    vertices : [N_GRID_VERTICES]GridVertex
    setup_grid_vertices(&vertices)
   
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
    create_vk_buffer(app, &app.grid_vertex_buffer, &vertex_buffer_create_info, &app.grid_vertex_buffer_memory, vb_property_flags)

    data : rawptr
    vk.MapMemory(app.device, staging_buffer_memory, 0, staging_buffer_create_info.size, {}, &data)
    intrinsics.mem_copy(data, raw_data(&vertices), size_of(vertices)) //mem_copy(destiny, source, len)
    vk.UnmapMemory(app.device, staging_buffer_memory)
    
    copy_buffer(app, staging_buffer, app.grid_vertex_buffer, size_of(vertices))
    vk.DestroyBuffer(app.device, staging_buffer, nil)
    vk.FreeMemory(app.device, staging_buffer_memory, nil)
}


setup_grid_vertices::proc(vertices : ^[N_GRID_VERTICES]GridVertex){
    vertices[0] = {f32(-1), f32(0), f32(-1)}

    vertices[1] = {f32(-1), f32(0), f32(1)}

    vertices[2] = {f32(1), f32(0), f32(-1)}

    vertices[3] = {f32(1), f32(0), f32(1)}
}


create_grid_index_buffer::proc(app : ^vkApplication){
    indices : [N_GRID_INDICES]u16 = {u16(0),u16(1),u16(2),u16(2),u16(3),u16(0)}
   
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
    create_vk_buffer(app, &app.grid_index_buffer, &index_buffer_create_info, &app.grid_index_buffer_memory, ib_property_flags)

    data : rawptr
    vk.MapMemory(app.device, staging_buffer_memory, 0, staging_buffer_create_info.size, {}, &data)
    intrinsics.mem_copy(data, raw_data(&indices), size_of(indices)) //mem_copy(destiny, source, len)
    vk.UnmapMemory(app.device, staging_buffer_memory)
    
    copy_buffer(app, staging_buffer, app.grid_index_buffer, size_of(indices))
    vk.DestroyBuffer(app.device, staging_buffer, nil)
    vk.FreeMemory(app.device, staging_buffer_memory, nil)
}



create_grid_pipeline::proc(app : ^vkApplication, vertex_binding_descriptions : ^[N_GRID_VERTEX_BINDINGS]vk.VertexInputBindingDescription, vertex_attribute_descriptions : ^[N_GRID_VERTEX_ATTRIBUTES]vk.VertexInputAttributeDescription){
    //Read vertex files bytes and check alignment
    vertex_shd_bytes, vtx_file_err := os.read_entire_file_from_path(GRID_VERTEX_SHADER_PATH, context.allocator)
    if vtx_file_err != nil{
	fmt.println("Couldnt read vertx_shader_file on pipeline creatinon")
    }
    defer delete(vertex_shd_bytes, context.allocator)
    if uintptr(raw_data(vertex_shd_bytes)) % 4 != 0{
	fmt.println("vertex bytes are not aligned aligned in pipeline creation")
    }
    vtx_shader := mem.slice_data_cast([]u32, vertex_shd_bytes)

    frag_shd_bytes, frag_file_err := os.read_entire_file_from_path(GRID_FRAGMENT_SHADER_PATH, context.allocator)
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
    vertex_input_state_info.vertexBindingDescriptionCount = N_GRID_VERTEX_BINDINGS
    vertex_input_state_info.pVertexBindingDescriptions = raw_data(vertex_binding_descriptions)
    vertex_input_state_info.vertexAttributeDescriptionCount = N_GRID_VERTEX_ATTRIBUTES
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
    descriptor_set_layouts : [1]vk.DescriptorSetLayout = {app.frame_descriptor_set_layout}
    pipeline_layout_info : vk.PipelineLayoutCreateInfo
    pipeline_layout_info.sType = vk.StructureType.PIPELINE_LAYOUT_CREATE_INFO
    pipeline_layout_info.setLayoutCount = 1
    pipeline_layout_info.pSetLayouts = raw_data(&descriptor_set_layouts)
    pipeline_layout_info.pushConstantRangeCount = 0
    pipeline_layout_info.pPushConstantRanges = nil //&push_constants_range 
    pipeline_layout_res := vk.CreatePipelineLayout(app.device, &pipeline_layout_info, nil,
	&app.grid_gp_layout)
    if pipeline_layout_res != vk.Result.SUCCESS{
	fmt.println("Error creating grid graphics_pipeline_layout")
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
    pipeline_info.layout = app.grid_gp_layout
    //pipeline_info.renderPass = app.render_pass //STATIC
    pipeline_info.renderPass = {}
    pipeline_info.subpass = 0

    graphic_pipeline_create_res := vk.CreateGraphicsPipelines(app.device, vk.PipelineCache{},
	1, &pipeline_info, nil, &app.grid_gp)

    if graphic_pipeline_create_res != vk.Result.SUCCESS{
	fmt.println("Error creating grid graphics_pipeline")
    }

    vk.DestroyShaderModule(app.device, vertex_shader_module, nil)
    vk.DestroyShaderModule(app.device, fragment_shader_module, nil)
}


