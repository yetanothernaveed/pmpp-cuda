#include <stdio.h>
#include <stdlib.h>

#define CUDA_CHECK(call) \
    do { \
        cudaError_t err = call; \
        if (err != cudaSuccess) { \
            fprintf(stderr, "CUDA Error at %s:%d - %s\n", \
                    __FILE__, __LINE__, cudaGetErrorString(err)); \
            exit(EXIT_FAILURE); \
        } \
    } while (0)

__global__
void vecAddKernel(float *A, float *B, float *C, int n) {
	int i = threadIdx.x + blockDim.x * blockIdx.x;
	if (i < n) {
		C[i] = A[i] + B[i];
	}
}

void vecAdd(float* A_h, float* B_h, float* C_h, int n) {
	int size = n * sizeof(float);
	float *A_d, *B_d, *C_d;

	// Part 1: Allocate device memory to A, B, and C
	CUDA_CHECK(cudaMalloc((void **)&A_d, size));
	CUDA_CHECK(cudaMalloc((void **)&B_d, size));
	CUDA_CHECK(cudaMalloc((void **)&C_d, size));
	// Copy A and B to device memory
	CUDA_CHECK(cudaMemcpy(A_d, A_h, size, cudaMemcpyHostToDevice));
	CUDA_CHECK(cudaMemcpy(B_d, B_h, size, cudaMemcpyHostToDevice));

	// Part 2: Call kernel - to launch a grid of threads
	// to perform the actual vector addition
	vecAddKernel<<<ceil(n / 256.0), 256>>>(A_d, B_d, C_d, n);

	// Part 3: Copy C from the device memory
	CUDA_CHECK(cudaMemcpy(C_h, C_d, size, cudaMemcpyDeviceToHost));
	// Free the device vectors
	CUDA_CHECK(cudaFree(A_d));
	CUDA_CHECK(cudaFree(B_d));
	CUDA_CHECK(cudaFree(C_d));
}

void printVec(float* A, int N) {
	for (int i = 0; i < N; ++i) {
		printf("%f ", A[i]);
	}
	printf("\n");
}

int main() {
	int size = 2000000;

	float *A = (float *)malloc(size * sizeof(float));
	float *B = (float *)malloc(size * sizeof(float));

	for (int i = 0; i < size; ++i) {
		A[i] = (float)i;
		B[i] = (float)(size - 1 - i);
	}

	// printVec(A, size);
	// printVec(B, size);

	float *C = (float *)malloc(size * sizeof(float));
	
	if (C == NULL) {
		printf("Malloc failed");
		return 1;
	}

	vecAdd(A, B, C, size);

	printVec(C, size);
	free(C);
}
