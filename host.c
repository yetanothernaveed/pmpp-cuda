#include <stdio.h>
#include <stdlib.h>

void vecAdd(float* A_h, float* B_h, float* C_h, int n) {
	for (int i = 0; i < n; i++) {
		C_h[i] = A_h[i] + B_h[i];
	}
}

void printVec(float* A, int N) {
	for (int i = 0; i < N; ++i) {
		printf("%f ", A[i]);
	}
	printf("\n");
}

int main() {
	int size = 5;

	float A[] = { 1, 2, 3, 4, 5 };
	float B[] = { 6, 7, 8, 9, 0 };
	float *C = (float *)malloc(size * sizeof(float));
	
	if (C == NULL) {
		printf("Malloc failed");
		return 1;
	}

	vecAdd(A, B, C, size);

	printVec(C, 5);
	free(C);
}
