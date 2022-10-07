cmake_minimum_required(VERSION 3.8)
project(Engine3D_cuda)
set(CMAKE_INCLUDE_CURRENT_DIR ON)

set(EGE_PATH_EX C:/Users/stophin/Source/github/xege.git/branches/xege-471b90e638f760846a3d6192c3f05be98b12f348)
set(EGE_PATH C:/Users/stophin/Source/ege19.01_all)
set(DX_PATH "C:/Program Files (x86)/Microsoft DirectX SDK (June 2010)")
set(CUDA_PATH "C:/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v11.7")
#add_definitions(-D_USING_GRAPHICS_QT)
add_definitions(-D_USING_GRAPHICS_EGE)
#add_definitions(-D_USING_GRAPHICS_DX)
#add_definitions(-D_USING_GRAPHICS_GDI)

set(LIBRARY_OUTPUT_PATH ${PROJECT_SOURCE_DIR}/output)
set(EXECUTABLE_OUTPUT_PATH ${PROJECT_SOURCE_DIR}/output)

FILE(GLOB SRC_FILES
	./common/*.cpp
	./platform/*.cpp
	./math3d/*.cpp
	./raytracing/*.cpp
	./scene/*.cpp
)

FILE(GLOB INC_FILES
	./common/*.h
	./platform/*.h
	./math3d/*.h
	./raytracing/*.h
	./scene/*.h
)
source_group(TREE ${PROJECT_SOURCE_DIR} PREFIX "Source Files" FILES ${SRC_FILES})
source_group(TREE ${PROJECT_SOURCE_DIR} PREFIX "Header Files" FILES ${INC_FILES})


find_package(CUDA REQUIRED)


cuda_add_executable(Engine3D_cuda kernel.cu ${SRC_FILES} ${INC_FILES})
#add_executable(Engine3D_cuda kernel.cu ${SRC_FILES} ${INC_FILES})

target_include_directories(Engine3D_cuda
	PUBLIC ${EGE_PATH_EX}/include/
	#PUBLIC ${EGE_PATH}/include/
	PUBLIC ${DX_PATH}/Include/
	#PUBLIC ${CUDA_PATH}/include/
)
target_link_directories(Engine3D_cuda
	PUBLIC ./
	PUBLIC ${EGE_PATH_EX}/lib/vs2019/x64/
	#PUBLIC ${EGE_PATH}/lib/vs2019/lib/x64/
	PUBLIC ${DX_PATH}/Lib/x64/
	#PUBLIC ${CUDA_PATH}/lib/x64/
)
target_link_libraries(Engine3D_cuda optimized ucrt.lib)
target_link_libraries(Engine3D_cuda d3d11.lib)
target_link_libraries(Engine3D_cuda 
	debug d3dx11d.lib optimized d3dx11.lib)
target_link_libraries(Engine3D_cuda 
	debug d3dx10d.lib optimized d3dx10.lib)
target_link_libraries(Engine3D_cuda gdiplus.lib)
#target_link_libraries(Engine3D_cuda cudart.lib)

set_target_properties(Engine3D_cuda PROPERTIES VS_DEBUGGER_WORKING_DIRECTORY ${EXECUTABLE_OUTPUT_PATH}/${CMAKE_CFG_INTDIR}/../)