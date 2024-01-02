#include "GpuSimulation.cuh"
#include "Lattice.hpp"
#include <iostream>

int __calculateBoundary(const std::vector<int> &inputBoundary)
{
    // calculate host boundary with streaming conventions.
    // 0 is no boundary, 1 is right, 2 is up, 3 is left, 4 is down, 5 is up-right, 6 is up-left, 7 is down-left, 8 is
    // down-right

    if (inputBoundary.at(0) == 0 && inputBoundary.at(1) == 0)
        return 0;
    else if (inputBoundary.at(0) == 1 && inputBoundary.at(1) == 0)
        return 1;
    else if (inputBoundary.at(0) == 0 && inputBoundary.at(1) == -1)
        return 2;
    else if (inputBoundary.at(0) == -1 && inputBoundary.at(1) == 0)
        return 3;
    else if (inputBoundary.at(0) == 0 && inputBoundary.at(1) == 1)
        return 4;
    else if (inputBoundary.at(0) == 1 && inputBoundary.at(1) == -1)
        return 5;
    else if (inputBoundary.at(0) == -1 && inputBoundary.at(1) == -1)
        return 6;
    else if (inputBoundary.at(0) == -1 && inputBoundary.at(1) == 1)
        return 7;
    else if (inputBoundary.at(0) == 1 && inputBoundary.at(1) == 1)
        return 8;
    else
        return -1;
}

__device__ void step1dev(const int nx, const int ny, const int it, const int problem_type, const float u_lid,
                         const float om_p, const float halfOmpOmmSum, const float halfOmpOmmSub, const int row,
                         const int col, float *f, float *new_f, float &rho, float &ux, float &uy, int &boundary)
{
    const int velocitiesX[9] = {0, 1, 0, -1, 0, 1, -1, -1, 1};
    const int velocitiesY[9] = {0, 0, -1, 0, 1, -1, -1, 1, 1};
    const float weights[9] = {4.0 / 9.0,  1.0 / 9.0,  1.0 / 9.0,  1.0 / 9.0, 1.0 / 9.0,
                              1.0 / 36.0, 1.0 / 36.0, 1.0 / 36.0, 1.0 / 36.0};
    const int opposite[9] = {0, 3, 4, 1, 2, 7, 8, 5, 6};

    // zouHe if it != 0
    if (it != 0)
    {
        // top wall
        if (boundary == 2)
        {
            rho = (f[0] + f[1] + f[3] + 2.0 * (f[2] + f[5] + f[6])) / (1.0 + uy);
            f[4] = f[2] - 2.0 / 3.0 * rho * uy;
            f[7] = f[5] + 0.5 * (f[1] - f[3]) - 0.5 * rho * ux - 1.0 / 6.0 * rho * uy;
            f[8] = f[6] - 0.5 * (f[1] - f[3]) + 0.5 * rho * ux - 1.0 / 6.0 * rho * uy;
        }
        // right wall
        else if (boundary == 1)
        {
            rho = (f[0] + f[2] + f[4] + 2.0 * (f[1] + f[5] + f[8])) / (1.0 + ux);
            f[3] = f[1] - 2.0 / 3.0 * rho * ux;
            f[6] = f[8] - 0.5 * (f[2] - f[4]) - 1.0 / 6.0 * rho * ux + 0.5 * rho * uy;
            f[7] = f[5] + 0.5 * (f[2] - f[4]) - 1.0 / 6.0 * rho * ux - 0.5 * rho * uy;
        }
        // bottom wall
        else if (boundary == 4)
        {
            rho = (f[0] + f[1] + f[3] + 2.0 * (f[4] + f[7] + f[8])) / (1.0 - uy);
            f[2] = f[4] + 2.0 / 3.0 * rho * uy;
            f[5] = f[7] - 0.5 * (f[1] - f[3]) + 0.5 * rho * ux + 1.0 / 6.0 * rho * uy;
            f[6] = f[8] + 0.5 * (f[1] - f[3]) - 0.5 * rho * ux + 1.0 / 6.0 * rho * uy;
        }
        // left wall
        else if (boundary == 3)
        {
            rho = (f[0] + f[2] + f[4] + 2.0 * (f[3] + f[6] + f[7])) / (1.0 - ux);
            f[1] = f[3] - 2.0 / 3.0 * rho * ux;
            f[5] = f[7] - 0.5 * (f[2] - f[4]) + 1.0 / 6.0 * rho * ux + 0.5 * rho * uy;
            f[8] = f[6] + 0.5 * (f[2] - f[4]) + 1.0 / 6.0 * rho * ux - 0.5 * rho * uy;
        }
        // top right corner
        else if (boundary == 5)
        {
            f[3] = f[1] - 2.0 / 3.0 * rho * ux;
            f[4] = f[2] - 2.0 / 3.0 * rho * uy;
            f[7] = f[5] - 1.0 / 6.0 * rho * ux - 1.0 / 6.0 * rho * uy;
            f[8] = 0;
            f[6] = 0;
            f[0] = rho - f[1] - f[2] - f[3] - f[4] - f[5] - f[7];
        }
        // bottom right corner
        else if (boundary == 8)
        {
            f[3] = f[1] - 2.0 / 3.0 * rho * ux;
            f[2] = f[4] + 2.0 / 3.0 * rho * uy;
            f[6] = f[8] + 1.0 / 6.0 * rho * uy - 1.0 / 6.0 * rho * ux;
            f[7] = 0;
            f[5] = 0;
            f[0] = rho - f[1] - f[2] - f[3] - f[4] - f[6] - f[8];
        }
        // bottom left corner
        else if (boundary == 7)
        {
            f[1] = f[3] + 2.0 / 3.0 * rho * ux;
            f[2] = f[4] + 2.0 / 3.0 * rho * uy;
            f[5] = f[7] + 1.0 / 6.0 * rho * ux + 1.0 / 6.0 * rho * uy;
            f[6] = 0;
            f[8] = 0;
            f[0] = rho - f[1] - f[2] - f[3] - f[4] - f[5] - f[7];
        }
        // top left corner
        else if (boundary == 6)
        {
            f[1] = f[3] + 2.0 / 3.0 * rho * ux;
            f[4] = f[2] - 2.0 / 3.0 * rho * uy;
            f[8] = f[6] - 1.0 / 6.0 * rho * ux + 1.0 / 6.0 * rho * uy;
            f[7] = 0;
            f[5] = 0;
            f[0] = rho - f[1] - f[2] - f[3] - f[4] - f[6] - f[8];
        }
    }

    // update macro
    rho = 0;
    ux = 0;
    uy = 0;
    for (int i = 0; i < 9; i++)
    {
        rho += f[i];
        ux += f[i] * velocitiesX[i];
        uy += f[i] * velocitiesY[i];
    }
    ux /= rho;
    uy /= rho;

    // set inlets
    if (problem_type == 1)
    {
        // if i'm a any boundary set ux uy to 0
        if (row == 0 || row == ny - 1 || col == 0 || col == nx - 1)
        {
            ux = 0;
            uy = 0;
        }
        // if i'm on the lid set ux to u_lid
        if (row == 0)
        {
            ux = u_lid;
        }
    }

    // equilibrium
    float feq[9];
    const float temp1 = 1.5 * (ux * ux + uy * uy);
    for (int i = 0; i < 9; i++)
    {
        const float temp2 = 3.0 * (velocitiesX[i] * ux + velocitiesY[i] * uy);
        feq[i] = weights[i] * rho * (1.0 + temp2 + 0.5 * temp2 * temp2 - temp1);
    }

    // collision for index 0
    new_f[0] = (1.0 - om_p) * f[0] + om_p * feq[0];

    // collision for other indices
    for (int i = 1; i < 9; i++)
    {
        new_f[i] = (1.0 - halfOmpOmmSum) * f[i] - halfOmpOmmSub * f[opposite[i]] + halfOmpOmmSum * feq[i] +
                   halfOmpOmmSub * feq[opposite[i]];
    }
}


__global__ void step1(const int nx, const int ny, const int it, const int problem_type,
                                     const float u_lid, const float om_p, const float halfOmpOmmSum,
                                     const float halfOmpOmmSub, float *f, float *new_f, float *rho, float *ux,
                                     float *uy, int *boundary, bool *obstacle)
{
    const int row = blockIdx.y * blockDim.y + threadIdx.y;
    const int col = blockIdx.x * blockDim.x + threadIdx.x;

    // return if out of bounds or obstacle
    if (row >= ny || col >= nx || obstacle[row * nx + col])
        return;

    const int index = row * nx + col;
    const int index9 = index * 9;

    step1dev(nx, ny, it, problem_type, u_lid, om_p, halfOmpOmmSum, halfOmpOmmSub, row, col, &f[index9], &new_f[index9],
             rho[index], ux[index], uy[index], boundary[index]);
}

__global__ void step2(const int nx, const int ny, float *f, float *new_f, int *boundary, bool *obstacle)
{
    const int row = blockIdx.y * blockDim.y + threadIdx.y;
    const int col = blockIdx.x * blockDim.x + threadIdx.x;

    // return if out of bounds or obstacle
    if (row >= ny || col >= nx || obstacle[row * nx + col])
        return;

    const int velocitiesX[9] = {0, 1, 0, -1, 0, 1, -1, -1, 1};
    const int velocitiesY[9] = {0, 0, -1, 0, 1, -1, -1, 1, 1};

    const int index = row * nx + col;
    const int index9 = index * 9;

    // stream for index 0
    f[index9] = new_f[index9];

    const int boundary_here = boundary[index];
    // stream for other indices
    for (int i = 1; i < 9; i++)
    {
        // check if there's a boundary in the way
        if ((velocitiesX[boundary_here] != velocitiesX[i] || velocitiesX[boundary_here] == 0) &&
            (velocitiesY[boundary_here] != velocitiesY[i] || velocitiesY[boundary_here] == 0))
        {
            // obtain new cell coordinates
            const int new_index9 = (row + velocitiesY[i]) * nx * 9 + (col + velocitiesX[i]) * 9;
            // stream
            f[new_index9 + i] = new_f[index9 + i];
        }
    }
}

void GpuSimulation::cudaCaller(const NDimensionalMatrix<Cell> &cells, const float sigma, const float omP,
                               const float omM, const int maxIt, const float uLid, const int problemType,
                               const Structure &structure, std::ofstream &file)
{
    const int nx = cells.getShape().at(0);
    const int ny = cells.getShape().at(1);
    const int totalSize = nx * ny;
    int timeInstant = 0;

    // device allocations

    float *host_f, *host_new_f, *host_rho, *host_ux, *host_uy, *dev_f, *dev_new_f, *dev_rho, *dev_ux, *dev_uy;
    int *host_boundary, *dev_boundary;
    bool *host_obstacle, *dev_obstacle;

    // allocate memory on device
    cudaMalloc((void **)&dev_f, totalSize * 9 * sizeof(float));
    cudaMalloc((void **)&dev_new_f, totalSize * 9 * sizeof(float));
    cudaMalloc((void **)&dev_rho, totalSize * sizeof(float));
    cudaMalloc((void **)&dev_ux, totalSize * sizeof(float));
    cudaMalloc((void **)&dev_uy, totalSize * sizeof(float));
    cudaMalloc((void **)&dev_boundary, totalSize * sizeof(int));
    cudaMalloc((void **)&dev_obstacle, totalSize * sizeof(bool));

    // allocate memory on host
    cudaMallocHost((void **)&host_f, totalSize * 9 * sizeof(float));
    cudaMallocHost((void **)&host_new_f, totalSize * 9 * sizeof(float));
    cudaMallocHost((void **)&host_rho, totalSize * sizeof(float));
    cudaMallocHost((void **)&host_ux, totalSize * sizeof(float));
    cudaMallocHost((void **)&host_uy, totalSize * sizeof(float));
    cudaMallocHost((void **)&host_boundary, totalSize * sizeof(int));
    cudaMallocHost((void **)&host_obstacle, totalSize * sizeof(bool));

    // set host data
    for (int i = 0; i < totalSize; ++i)
    {
        const Cell &cell = cells.getElementAtFlatIndex(i);
        const std::vector<float> &f = cell.getF();
        const std::vector<float> &new_f = cell.getNewF();
        const std::vector<float> &macroU = cell.getMacroU();
        const std::vector<int> &boundary = cell.getBoundary();
        const bool &obstacle = cell.isObstacle();

        for (int j = 0; j < 9; ++j)
        {
            host_f[i * 9 + j] = f.at(j);
            host_new_f[i * 9 + j] = new_f.at(j);
        }
        host_rho[i] = cell.getRho();
        host_ux[i] = macroU.at(0);
        host_uy[i] = macroU.at(1);
        host_boundary[i] = __calculateBoundary(boundary);
        host_obstacle[i] = obstacle;
    }

    // copy host data to device
    cudaMemcpy(dev_f, host_f, totalSize * 9 * sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(dev_new_f, host_new_f, totalSize * 9 * sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(dev_rho, host_rho, totalSize * sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(dev_ux, host_ux, totalSize * sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(dev_uy, host_uy, totalSize * sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(dev_boundary, host_boundary, totalSize * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(dev_obstacle, host_obstacle, totalSize * sizeof(bool), cudaMemcpyHostToDevice);

    // free host memory
    cudaFreeHost(host_f);
    cudaFreeHost(host_new_f);
    cudaFreeHost(host_rho);
    cudaFreeHost(host_boundary);
    cudaFreeHost(host_obstacle);

    const dim3 threadsPerBlock(24, 24);
    const dim3 numBlocks(ceil(nx / 24.0), ceil(ny / 24.0));
    // loop
    const float temp = 2.0 * sigma * sigma;
    const float halfOmpOmmSub = 0.5 * (omP - omM);
    const float halfOmpOmmSum = 0.5 * (omP + omM);
    while (timeInstant <= maxIt)
    {
        const float uLidNow = uLid * (1.0 - std::exp(-static_cast<double>(timeInstant * timeInstant) / temp));
        step1<<<numBlocks, threadsPerBlock>>>(nx, ny, timeInstant, problemType, uLidNow, omP,
                                                             halfOmpOmmSum, halfOmpOmmSub, dev_f, dev_new_f, dev_rho,
                                                             dev_ux, dev_uy, dev_boundary, dev_obstacle);
        step2<<<numBlocks, threadsPerBlock>>>(nx, ny, dev_f, dev_new_f, dev_boundary, dev_obstacle);

        // write to file every maxIt/100 time steps
        if (timeInstant % (maxIt / 100) == 0)
        {
            // copy ux and uy to host
            cudaMemcpy(host_ux, dev_ux, totalSize * sizeof(float), cudaMemcpyDeviceToHost);
            cudaMemcpy(host_uy, dev_uy, totalSize * sizeof(float), cudaMemcpyDeviceToHost);
            // write to file time instant
            file << timeInstant << '\n';

            // write ux
            for (int i = 0; i < totalSize; ++i)
            {
                file << host_ux[i] << ' ';
            }
            file << '\n';
            // write uy
            for (int i = 0; i < totalSize; ++i)
            {
                file << host_uy[i] << ' ';
            }
            file << '\n';
            // print to console
            std::cout << "Time step: " << timeInstant << '\n';
        }

        // advance time
        timeInstant++;
    }
    cudaFreeHost(host_ux);
    cudaFreeHost(host_uy);
}
