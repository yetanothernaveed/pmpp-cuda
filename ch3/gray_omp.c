#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_WRITE_IMPLEMENTATION
#define NUM_CHANNELS 3

#include <stdio.h>
#include <stdlib.h>
#include "headers/stb_image.h"
#include "headers/stb_image_write.h"
#include <omp.h>

void colorToGrayscaleConvertion(unsigned char* Pout, unsigned char* Pin, int width, int height) {
    #pragma omp parallel for
    for (int r = 0; r < height; ++r) {
        for (int c = 0; c < width; ++c) {
            int grayOffset = (r * width + c);
            int rgbOffset = grayOffset * NUM_CHANNELS;

            unsigned char R = Pin[rgbOffset];
            unsigned char G = Pin[rgbOffset + 1];
            unsigned char B = Pin[rgbOffset + 2];

            Pout[grayOffset] = 0.21f * R + 0.71f * G + 0.07f * B;
        }
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

    size_t Pout_size = (size_t)(n * m * CHANNELS);
    unsigned char* Pout_h = (unsigned char*)malloc(Pout_size);
    if (Pout_h == NULL) {
        fprintf(stderr, "Error allocating memory from output grayscale image");
        return EXIT_FAILURE;
    }

    double start_time = omp_get_wtime();

    colorToGrayscaleConvertion(Pout_h, Pin_h, m, n);

    double end_time = omp_get_wtime();
    double time_taken = end_time - start_time;

    printf("Compute time: %f seconds\n", time_taken);

    // Arguments: filename, width, height, channel_count (1 for gray), buffer, quality (1-100)
    if (!stbi_write_jpg("output/image_gray.jpg", m, n, 1, Pout_h, 1)) {
        fprintf(stderr, "Failed to save image!\n");
    }

    stbi_image_free(Pin_h);
    free(Pout_h);
    return EXIT_SUCCESS;
}
