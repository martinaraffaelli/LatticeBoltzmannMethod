#include "Lattice.hpp"
#include <iostream>
#include <omp.h>

Lattice::Lattice(std::ifstream &file_in, const int plotSteps) : plotSteps(plotSteps)
{

    // read type of problem
    file_in >> problemType;
    file_in.get(); // Skip the newline

    // Read the number of cells in each dimension until newline
    std::vector<int> shape;
    int dimensions = 0;
    while (file_in.peek() != '\n')
    {
        int numCells;
        file_in >> numCells;
        shape.push_back(numCells);
        ++dimensions;
    }
    if (dimensions == 2)
    {
        structure = Structure::D2Q9;
    }
    /*
    else if (dimensions == 3)
    {
        structure = Structure::D3Q27;
    }
    */
    else
    {
        throw std::runtime_error("Invalid number of dimensions");
    }
    file_in.get(); // Skip the newline

    // Read Reynolds number
    float reynolds;
    file_in >> reynolds;

    // Read the simulation time
    float simulationTime;
    file_in >> simulationTime;

    if (problemType == 1)
    {
        file_in >> uLid;
    }
    else
        uLid = 0.2;
    file_in.get(); // Skip the newline

    // calculate simulation parameters
    sigma = 10.0 * shape.at(0);
    omP = 1.0 / (0.5 + 3.0 * uLid * shape.at(0) / reynolds);
    omM = 1.0 / (1.0 / (12.0 * uLid * shape.at(0) / reynolds) + 0.5);
    maxIt = (int)std::round(simulationTime * shape.at(0) / uLid);
    if (problemType == 2)
    {
        maxIt = (int)std::round(simulationTime / 0.05);
    }

    // Initialize the cells
    cells = NDimensionalMatrix<Cell>(shape);

    // Read the obstacles : for each newline, read the coordinates of the obstacle
    NDimensionalMatrix<bool> obstacles(shape);
    for (int i = 0; i < obstacles.getTotalSize(); ++i)
    {
        obstacles.setElementAtFlatIndex(i, false);
    }
    while (file_in.peek() != EOF)
    {
        std::vector<int> indices;
        for (int i = 0; i < dimensions; ++i)
        {
            int index;
            file_in >> index;
            indices.push_back(index);
        }
        obstacles.setElement(indices, true);
        file_in.get(); // Skip the newline
    }

    //  Initialize the cells one by one
    std::vector<float> f;
    std::vector<int> boundary;
    std::vector<int> indices;

    for (int i = 0; i < cells.getTotalSize(); ++i)
    {
        indices = cells.getIndicesAtFlatIndex(i);
        const bool &obstacle = obstacles.getConstCopy(indices.at(0), indices.at(1));

        boundary.clear();
        f.clear();

        const int numDiag = 2; // if dimensions = 2, otherwhise we need to define it in other way

        for (int k = 0; k < dimensions; ++k) // only checks in the directions of x and y
        {
            // first we initialize the boundary given by walls, then (checkin which dimension we are in) we
            // initialize the boundary given by obstacles otherwise the boundary is 0
            const int indexOfCurrDimension = indices.at(k);
            const int lenghtOfCurrDimension = shape.at(k);
            if (indexOfCurrDimension == 0)
            {
                boundary.push_back(0);
            }
            else if (indexOfCurrDimension == lenghtOfCurrDimension - 1)
            {
                boundary.push_back(0);
            }
            else
            {
                if (k == 0)
                {
                    if (obstacles.getConstCopy(indices.at(0) - 1, indices.at(1)))
                    {
                        boundary.push_back(-1);
                    }
                    else if (obstacles.getConstCopy(indices.at(0) + 1, indices.at(1)))
                    {
                        boundary.push_back(1);
                    }
                    else
                        boundary.push_back(0);
                }
                else if (k == 1)
                {
                    if (obstacles.getConstCopy(indices.at(0), indices.at(1) - 1))
                    {
                        boundary.push_back(-1);
                    }
                    else if (obstacles.getConstCopy(indices.at(0), indices.at(1) + 1))
                    {
                        boundary.push_back(1);
                    }
                    else
                        boundary.push_back(0);
                }
                else
                {
                    boundary.push_back(0);
                }
            }
        }
        for (int k = dimensions; k < dimensions + numDiag; k++)
        {
            if (k == dimensions)
            {
                if (indices.at(0) == 0 || indices.at(0) == cells.getShape().at(0) - 1 || indices.at(1) == 0 ||
                    indices.at(1) == cells.getShape().at(1) - 1)
                {
                    boundary.push_back(0);
                }
                else if ((indices.at(0) + 1 < shape.at(0)) && (indices.at(1) + 1 < shape.at(1)) &&
                         obstacles.getConstCopy(indices.at(0) + 1, indices.at(1) + 1))
                {
                    boundary.push_back(1);
                }
                else if ((indices.at(0) - 1 >= 0) && (indices.at(1) - 1 >= 0) &&
                         obstacles.getConstCopy(indices.at(0) - 1, indices.at(1) - 1))
                {
                    boundary.push_back(-1);
                }
                else
                {
                    boundary.push_back(0);
                }
            }
            else
            {
                // consider the diagonal that goes from the bottom left to the top right
                // if the cell on the bottom left is an obstacle, the boundary is 1
                // if the cell on the top right is an obstacle, the boundary is -1
                // otherwise the boundary is 0
                if (indices.at(0) == 0 || indices.at(0) == cells.getShape().at(0) - 1 || indices.at(1) == 0 ||
                    indices.at(1) == cells.getShape().at(1) - 1)
                {
                    boundary.push_back(0);
                }
                else if ((indices.at(0) - 1 >= 0) && (indices.at(1) + 1 < shape.at(1)) &&
                         obstacles.getConstCopy(indices.at(0) - 1, indices.at(1) + 1))
                {
                    boundary.push_back(1);
                }
                else if ((indices.at(1) - 1 >= 0) && (indices.at(0) + 1 < shape.at(1)) &&
                         obstacles.getConstCopy(indices.at(0) + 1, indices.at(1) - 1))
                {
                    boundary.push_back(-1);
                }
                else
                {
                    boundary.push_back(0);
                }
            }
        }

        cells.setElementAtFlatIndex(i, Cell(structure, boundary, obstacle, indices));
        cells.getElementAtFlatIndex(i).initEq(structure, omP, 0.5 * (omP + omM), 0.5 * (omP - omM));

    }
}

void Lattice::simulate(std::ofstream &velocity_out, std::ofstream &lift_drag_out)
{
    const float temp = 2.0 * sigma * sigma;
    const float halfOmpOmmSub = 0.5 * (omP - omM);
    const float halfOmpOmmSum = 0.5 * (omP + omM);
    float drag, lift;
    const float tempDL = -2.0 / (0.11 * std::floor(getShape().at(1) * 0.43)); //temp for drag and lift

    while (timeInstant <= maxIt)
    {
        const float uLidNow = uLid * (1.0 - std::exp(-static_cast<double>(timeInstant * timeInstant) / temp));

#pragma omp parallel
        {
#pragma omp for
            // inlets, zouhe, bb, macro, eq coll
            for (int j = 0; j < cells.getTotalSize(); ++j)
            {
                cells.getElementAtFlatIndex(j).setInlets(*this, uLidNow);
                cells.getElementAtFlatIndex(j).zouHe(*this, uLidNow);
                cells.getElementAtFlatIndex(j).updateMacro(structure);
                cells.getElementAtFlatIndex(j).equilibriumCollision(structure, omP, halfOmpOmmSum, halfOmpOmmSub);
                cells.getElementAtFlatIndex(j).bounce_back_obstacle();
            }

#pragma omp for
            // streaming
            for (int j = 0; j < cells.getTotalSize(); ++j)
            {
                cells.getElementAtFlatIndex(j).streaming(*this);
            }

            // drag and lift if problemType == 2 and about to print
            if (problemType == 2 && timeInstant % (maxIt / plotSteps) == 0)
            {
                #pragma omp single
                {
                drag = 0;
                lift = 0;
                }


#pragma omp for
                for (int j = 0; j < cells.getTotalSize(); ++j)
                {
                    cells.getElementAtFlatIndex(j).dragAndLift(drag,lift);
                }

            
            }
        }

        // write to files every maxIt/plotSteps time steps
        if (timeInstant % (maxIt / plotSteps) == 0)
        {
            // write to files time instant
            velocity_out << timeInstant << '\n';
            lift_drag_out << timeInstant << '\n';

            // loop dimensions
            for (int i = 0; i < structure.dimensions; ++i)
            {
                // write to file macroU
                for (int j = 0; j < cells.getTotalSize(); ++j)
                {
                    velocity_out << cells.getElementAtFlatIndex(j).getMacroU().at(i) << ' ';
                }
                velocity_out << '\n';
            }

            // lift and drag
            if (problemType == 2)
            {
                lift_drag_out << drag << ' ' << lift << '\n';

            }

            // print to console
            std::cout << "Time step: " << timeInstant << '\n';
        }

        // advance time
        timeInstant++;
    }
}

#ifdef USE_CUDA
#include "GpuSimulation.cuh"
/// @brief supports only 2D lattice
void Lattice::simulateGpu(std::ofstream &velocity_out, std::ofstream &lift_drag_out)
{
    GpuSimulation::cudaCaller(cells, sigma, omP, omM, maxIt, uLid, problemType, structure, plotSteps, velocity_out,
                              lift_drag_out);
}
#endif

Cell &Lattice::getCellAtIndices(const std::vector<int> &indices)
{
    return cells.getElement(indices);
}

Cell &Lattice::getCellAtIndices(const int x, const int y)
{
    return cells.getElement(x, y);
}

Cell &Lattice::getCellAtIndices(const int *indices)
{
    if (structure.dimensions == 2)
        return cells.getElement(indices[0], indices[1]);

    else if (structure.dimensions == 3)
        return cells.getElement(indices[0], indices[1], indices[2]);

    else
        throw std::runtime_error("Invalid number of dimensions");
}

Cell &Lattice::getCellAtIndices(const int x, const int y, const int z)
{
    return cells.getElement(x, y, z);
}

const Cell &Lattice::getCellAtIndex(const int index) const
{
    return cells.getElementAtFlatIndex(index);
}

const std::vector<int> Lattice::getShape() const
{
    return cells.getShape();
}

const Structure &Lattice::getStructure() const
{
    return structure;
}

const std::vector<float> &Lattice::getCloseU(const std::vector<int> &indices)
{
    const int xLen = getShape().at(0);

    // left wall
    if (indices.at(0) == 0)
        return getCellAtIndices(indices.at(0) + 1, indices.at(1)).getMacroU();
    // right wall
    if (indices.at(0) == xLen - 1)
        return getCellAtIndices(indices.at(0) - 1, indices.at(1)).getMacroU();

    else
        throw std::runtime_error("Invalid indices");
}

float Lattice::getCloseRho(const std::vector<int> &indices)
{
    const int xLen = getShape().at(0) - 1;
    const int yLen = getShape().at(1) - 1;
    if (indices.at(0) == 0 && indices.at(1) == yLen) // bottom left corner
        return getCellAtIndices(indices.at(0) + 1, indices.at(1)).getRho();

    if (indices.at(0) == xLen && indices.at(1) == yLen) // bottom right corner
        return getCellAtIndices(indices.at(0) - 1, indices.at(1)).getRho();

    if (indices.at(0) == 0 && indices.at(1) == 0) // top left corner
        return getCellAtIndices(indices.at(0) + 1, indices.at(1)).getRho();

    if (indices.at(0) == xLen && indices.at(1) == 0) // top right corner
        return getCellAtIndices(indices.at(0) - 1, indices.at(1)).getRho();

    else
        throw std::runtime_error("Invalid indices");
}

int Lattice::getProblemType() const
{
    return problemType;
}
