// nvcc -O3 gray_gpu.cu -o gray_gpu
// ./gray_gpu input/image.jpg

#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_WRITE_IMPLEMENTATION
#define NUM_CHANNELS 3

#define CUDA_CHECK(call) \
    do { \
        cudaError_t err = call; \
        if (err != cudaSuccess) { \
            fprintf(stderr, "CUDA Error at %s:%d - %s\n", \
                    __FILE__, __LINE__, cudaGetErrorString(err)); \
            exit(EXIT_FAILURE); \
        } \
    } while (0)

#include <stdio.h>
#include <stdlib.h>
#include "headers/stb_image.h"
#include "headers/stb_image_write.h"
// #include <omp.h>

__global__
void colorToGrayscaleConvertion(unsigned char* Pout, unsigned char* Pin, int width, int height) {
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    int row = blockIdx.y * blockDim.y + threadIdx.y;

    if (row < height && col < width) {
        int grayOffset = row * width + col;
        int rgbOffset = grayOffset * NUM_CHANNELS;

        unsigned char R = Pin[rgbOffset];
        unsigned char G = Pin[rgbOffset + 1];
        unsigned char B = Pin[rgbOffset + 2];

        Pout[grayOffset] = R * 0.21f + G * 0.71f + B * 0.07f;
    }
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Error: Missing file path argument.\n");
        fprintf(stderr, "Usage: %s <path_to_image>\n", argv[0]);
        return EXIT_FAILURE;
    }

    const char* file_path = argv[1];
    FILE* file = fopen(file_path, "rb");
    if (!file) {
        fprintf(stderr, "Error: The file '%s' does not exist or cannot be opened.\n", file_path);
        return EXIT_FAILURE;
    }
    fclose(file);
    
    int n; // number of pixels in y direction, rows
    int m; // number of pixels in x direction, columns
    int CHANNELS;
    
    unsigned char* Pin_h = stbi_load(file_path, &m, &n, &CHANNELS, 3);
    if (Pin_h == NULL) {
        fprintf(stderr, "Error loading image: %s\n", stbi_failure_reason());
        return EXIT_FAILURE;
    }

    size_t Pout_h_size = (size_t)(n * m);
    unsigned char* Pout_h = (unsigned char*)malloc(Pout_h_size);
    if (Pout_h == NULL) {
        fprintf(stderr, "Error allocating memory from output grayscale image");
        return EXIT_FAILURE;
    }

    // Allocate space in device
    unsigned char *Pin_d, *Pout_d;
    size_t Pin_size = n * m * NUM_CHANNELS;
    size_t Pout_size = n * m;
    CUDA_CHECK(cudaMalloc((void **)&Pin_d, n * m * NUM_CHANNELS));
    CUDA_CHECK(cudaMalloc((void**)&Pout_d, n * m));

    // Move data to device
    CUDA_CHECK(cudaMemcpy(Pin_d, Pin_h, Pin_size, cudaMemcpyHostToDevice));

    // Execute Kernel
    dim3 dimBlock(16, 16, 1);
    dim3 dimGrid((m + dimBlock.x - 1) / dimBlock.x, (n + dimBlock.y - 1) / dimBlock.y, 1);

    colorToGrayscaleConvertion<<<dimGrid, dimBlock>>>(Pout_d, Pin_d, m, n);
    CUDA_CHECK(cudaGetLastError());

    // Bring processed gray image back to into host memory
    CUDA_CHECK(cudaMemcpy(Pout_h, Pout_d, Pout_size, cudaMemcpyDeviceToHost));

    // Write to file
    // Arguments: filename, width, height, channel_count (1 for gray), buffer, quality (1-100)
    if (!stbi_write_jpg("output/image_gray.jpg", m, n, 1, Pout_h, 90)) {
        fprintf(stderr, "Failed to save image!\n");
    }

    stbi_image_free(Pin_h);
    free(Pout_h);
    cudaFree(Pin_d);
    cudaFree(Pout_d);
    
    return EXIT_SUCCESS;
}
