// Note: the kernel example given in Fig 3.8 does not account for RGB channels.

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
#define PATCH_SIZE 100
#define BLUR_SIZE ((PATCH_SIZE - 1) / 2)

#include <stdio.h>
#include <stdlib.h>
#include "headers/stb_image.h"
#include "headers/stb_image_write.h"

__global__
void rgbBlurKernel(unsigned char* Pout, const unsigned char* Pin, int width, int height) {
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    int row = blockIdx.y * blockDim.y + threadIdx.y;

    if (row < height && col < width) {
        int rPixVal = 0; int gPixVal = 0; int bPixVal = 0;
        int pixels = 0;

        for (int dy = -BLUR_SIZE; dy <= BLUR_SIZE; ++dy) {
            for (int dx = -BLUR_SIZE; dx <= BLUR_SIZE; ++dx) {
                int pixRow = row + dy;
                int pixCol = col + dx;

                if (pixRow >= 0 && pixRow < height && pixCol >= 0 && pixCol < width) {
                    int pixRgbOffset = (pixRow * width + pixCol) * NUM_CHANNELS;
                    
                    rPixVal += (int)Pin[pixRgbOffset];
                    gPixVal += (int)Pin[pixRgbOffset + 1];
                    bPixVal += (int)Pin[pixRgbOffset + 2];

                    ++pixels;
                }
            }
        }

        int rgbOffset = (row * width + col) * NUM_CHANNELS;
        Pout[rgbOffset] = (unsigned char)(rPixVal / pixels);
        Pout[rgbOffset + 1] = (unsigned char)(gPixVal / pixels);
        Pout[rgbOffset + 2] = (unsigned char)(bPixVal / pixels);
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
    
    int height; // number of pixels in y direction, rows
    int width; // number of pixels in x direction, columns
    int CHANNELS;
    
    unsigned char* Pin_h = stbi_load(file_path, &width, &height, &CHANNELS, 3);
    if (Pin_h == NULL) {
        fprintf(stderr, "Error loading image: %s\n", stbi_failure_reason());
        return EXIT_FAILURE;
    }

    // Calculate the size of the input and output images in bytes
    size_t Pin_size = (size_t)height * width * NUM_CHANNELS * sizeof(unsigned char);
    size_t Pout_size = (size_t)height * width * NUM_CHANNELS * sizeof(unsigned char);

    // Allocate memory for host output image
    unsigned char* Pout_h = (unsigned char*)malloc(Pout_size);
    if (Pout_h == NULL) {
        fprintf(stderr, "Error allocating memory from output blurred image");
        return EXIT_FAILURE;
    }

    // Allocate space in device
    unsigned char *Pin_d, *Pout_d;
    CUDA_CHECK(cudaMalloc((void **)&Pin_d, Pin_size));
    CUDA_CHECK(cudaMalloc((void **)&Pout_d, Pout_size));

    // Move data to device
    CUDA_CHECK(cudaMemcpy(Pin_d, Pin_h, Pin_size, cudaMemcpyHostToDevice));

    // Execute Kernel
    dim3 dimBlock(16, 16, 1);
    dim3 dimGrid((width + dimBlock.x - 1) / dimBlock.x, (height + dimBlock.y - 1) / dimBlock.y, 1);

    rgbBlurKernel<<<dimGrid, dimBlock>>>(Pout_d, Pin_d, width, height);
    CUDA_CHECK(cudaGetLastError());

    // Bring processed blurred image back to into host memory
    CUDA_CHECK(cudaMemcpy(Pout_h, Pout_d, Pout_size, cudaMemcpyDeviceToHost));

    // Write to file
    // Arguments: filename, width, height, channel_count (3 for RGB), buffer, quality (1-100)
    if (!stbi_write_jpg("output/image_blur.jpg", width, height, 3, Pout_h, 90)) {
        fprintf(stderr, "Failed to save image!\n");
    }

    stbi_image_free(Pin_h);
    free(Pout_h);
    cudaFree(Pin_d);
    cudaFree(Pout_d);
    
    return EXIT_SUCCESS;
}
