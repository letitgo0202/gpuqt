/*
    Copyright 2017 Zheyong Fan, Ville Vierimaa, and Ari Harju

    This file is part of GPUQT.

    GPUQT is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    GPUQT is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with GPUQT.  If not, see <http://www.gnu.org/licenses/>.
*/




#include "model.h"
#include <random>
#include <iostream>
#include <fstream>
#include <limits.h>




void Model::add_anderson_disorder()
{
    real W2 = anderson_disorder_strength * 0.5;
    std::uniform_real_distribution<real> on_site_potential(-W2, W2);
    for (int n = 0; n < number_of_atoms; ++n)
    {
        potential[n] = on_site_potential(generator);
    }
}




void Model::create_random_numbers
(int max_value, int total_number, int* random_numbers)
{
    int *permuted_numbers = new int[max_value];
    for(int i = 0; i < max_value; ++i)
    {
        permuted_numbers[i] = i;
    }
    std::uniform_int_distribution<int> rand_int(0, INT_MAX);
    for(int i = 0; i < max_value; ++i)
    {
        int j = rand_int(generator) % (max_value - i) + i;
        int temp = permuted_numbers[i];
        permuted_numbers[i] = permuted_numbers[j];
        permuted_numbers[j] = temp;
    }
    for (int i = 0; i < total_number; ++i)
    {
        random_numbers[i] = permuted_numbers[i];
    }
    delete[] permuted_numbers;
}




void Model::specify_vacancies
(int *is_vacancy, int number_of_atoms_pristine)
{
    int *vacancy_indices = new int[number_of_vacancies];
    create_random_numbers
    (number_of_atoms_pristine, number_of_vacancies, vacancy_indices);

    for (int n = 0; n < number_of_atoms_pristine; ++n)
    {
        is_vacancy[n] = 0;
    }
    for (int n = 0; n < number_of_vacancies; ++n)
    {
        is_vacancy[vacancy_indices[n]] = 1;
    }
    delete[] vacancy_indices;
}




void Model::find_new_atom_index
(int *is_vacancy, int *new_atom_index, int number_of_atoms_pristine)
{
    int count = 0;
    for (int n = 0; n < number_of_atoms_pristine; ++n)
    {
        if (is_vacancy[n] == 0)
        {
            new_atom_index[n] = count;
            ++count;
        }
    }
}




void Model::add_vacancies()
{
    // copy some data
    int *neighbor_number_pristine = new int[number_of_atoms];
    int *neighbor_list_pristine = new int[number_of_pairs];
    real *hopping_real_pristine = new real[number_of_pairs];
    real *hopping_imag_pristine = new real[number_of_pairs];
    real *xx_pristine = new real[number_of_pairs];

    for (int n = 0; n < number_of_atoms; ++n)
    {
        neighbor_number_pristine[n] = neighbor_number[n];
    }   
    for (int m = 0; m < number_of_pairs; ++m)
    {
        neighbor_list_pristine[m] = neighbor_list[m];
        hopping_real_pristine[m] = hopping_real[m];
        hopping_imag_pristine[m] = hopping_imag[m];
        xx_pristine[m] = xx[m];
    }

    // change parameters
    int number_of_atoms_pristine = number_of_atoms;
    number_of_atoms = number_of_atoms_pristine - number_of_vacancies;
    number_of_pairs = number_of_atoms * max_neighbor;

    // delete old memory
    delete[] neighbor_number;
    delete[] neighbor_list;
    delete[] hopping_real;
    delete[] hopping_imag;
    delete[] xx;

    // allocate new memory
    neighbor_number = new int[number_of_atoms];
    neighbor_list = new int[number_of_pairs];
    hopping_real = new real[number_of_pairs];
    hopping_imag = new real[number_of_pairs];
    xx = new real[number_of_pairs];

    // specify the distribution of the vacancies
    int *is_vacancy = new int[number_of_atoms_pristine];
    specify_vacancies(is_vacancy, number_of_atoms_pristine);

    // find the new indices of the atoms
    int *new_atom_index = new int[number_of_atoms_pristine];
    find_new_atom_index(is_vacancy, new_atom_index, number_of_atoms_pristine);

    // get the new neighbor structure and related data
    int count_atom = 0;
    for (int n = 0; n < number_of_atoms_pristine; ++n)
    {
        if (is_vacancy[n] == 0)
        {
            int count_neighbor = 0;
            for (int m = 0; m < neighbor_number_pristine[n]; ++m)
            {
                int index_old = n * max_neighbor + m;
                int k = neighbor_list_pristine[index_old];
                if (is_vacancy[k] == 0)
                {
                    int index_new = count_atom * max_neighbor + count_neighbor;
                    neighbor_list[index_new] = new_atom_index[k];
                    hopping_real[index_new] = hopping_real_pristine[index_old];
                    hopping_imag[index_new] = hopping_imag_pristine[index_old];
                    xx[index_new] = xx_pristine[index_old];
                    ++count_neighbor;
                }
            }
            neighbor_number[count_atom] = count_neighbor;
            ++count_atom;
        }
    }

    // free memory
    delete[] neighbor_number_pristine;
    delete[] neighbor_list_pristine;
    delete[] hopping_real_pristine;
    delete[] hopping_imag_pristine;
    delete[] xx_pristine;
    delete[] is_vacancy;
    delete[] new_atom_index;
}




void Model::add_charged_impurities()
{
    real charged_impurity_range_square = charged_impurity_range
                                       * charged_impurity_range;
    real box_length_half[3];
    for (int d = 0; d < 3; ++d) 
        box_length_half[d] = box_length[d] * 0.5;

    int *impurity_indices = new int[number_of_charged_impurities];
    real *impurity_strength = new real[number_of_charged_impurities];

    create_random_numbers
    (number_of_atoms, number_of_charged_impurities, impurity_indices);

    real W2 = charged_impurity_strength * 0.5;
    std::uniform_real_distribution<real> strength(-W2, W2);
    for (int i = 0; i < number_of_charged_impurities; ++i)
    {
        impurity_strength[i] = strength(generator);
    }

    for (int n1 = 0; n1 < number_of_atoms; ++n1)
    {
        potential[n1] = 0.0;

        real x1 = x[n1];
        real y1 = y[n1];
        real z1 = z[n1];
        for (int i = 0; i < number_of_charged_impurities; ++i)
        {
            int n2 = impurity_indices[i];
            real r12[3];
            r12[0] = x[n2] - x1;
            r12[1] = y[n2] - y1;
            r12[2] = z[n2] - z1;
            real d12_square = 0.0;
            for (int d = 0; d < 3; ++d)
            {
                r12[d] = fabs(r12[d]);
                if (pbc[d] == 1 && r12[d] > box_length_half[d])
                {
                    r12[d] = box_length[d] - r12[d];
                }
                d12_square += r12[d] * r12[d];
            }

            d12_square /= charged_impurity_range_square;
            potential[n1] += impurity_strength[i]*exp(-d12_square*0.5);
        }
    }

    delete[] impurity_indices;
    delete[] impurity_strength;
}




static int find_index
(int nx, int ny, int nz, int Nx, int Ny, int Nz, int m, int N_orbital)
{
    if (nx < 0) nx += Nx;
    if (nx >= Nx) nx -= Nx;
    if (ny < 0) ny += Ny;
    if (ny >= Ny) ny -= Ny;
    if (nz < 0) nz += Nz;
    if (nz >= Nz) nz -= Nz;
    return ((nx * Ny + ny) * Nz + nz) * N_orbital + m;
}




void Model::initialize_lattice_model()
{
    std::string filename = input_dir + "/lattice.in";
    print_started_reading(filename);
    std::ifstream input(filename);

    if (!input.is_open())
    {
        std::cout <<"Could not open " + filename << std::endl;
        exit(1);
    }

    int N_orbital;
    int transport_direction;
    int N_cell[3];
    real lattice_constant[3];

    input >> N_cell[0] >> N_cell[1] >> N_cell[2];
    std::cout << "- Number of cells in the x direction = "
              << N_cell[0] << std::endl;
    if (N_cell[0] <= 0)
    {
        std::cout << "Error: Number of cells in the x direction should > 0"
                  << std::endl;
        exit(1);
    }
    std::cout << "- Number of cells in the y direction = "
              << N_cell[1] << std::endl;
    if (N_cell[1] <= 0)
    {
        std::cout << "Error: Number of cells in the y direction should > 0"
                  << std::endl;
        exit(1);
    }
    std::cout << "- Number of cells in the z direction = "
              << N_cell[2] << std::endl;
    if (N_cell[2] <= 0)
    {
        std::cout << "Error: Number of cells in the z direction should > 0"
                  << std::endl;
        exit(1);
    }

    input >> pbc[0] >> pbc[1] >> pbc[2] >> transport_direction;

    if (pbc[0] == 1)
    {
        std::cout << "- x direction has periodic boundary" << std::endl;
    }
    else if (pbc[0] == 0)
    {
        std::cout << "- x direction has open boundary" << std::endl;
    }
    else
    {
        std::cout << "Error: x direction has wrong boundary" << std::endl;
        exit(1);
    }

    if (pbc[1] == 1)
    {
        std::cout << "- y direction has periodic boundary" << std::endl;
    }
    else if (pbc[1] == 0)
    {
        std::cout << "- y direction has open boundary" << std::endl;
    }
    else
    {
        std::cout << "Error: y direction has wrong boundary" << std::endl;
        exit(1);
    }

    if (pbc[2] == 1)
    {
        std::cout << "- z direction has periodic boundary" << std::endl;
    }
    else if (pbc[2] == 0)
    {
        std::cout << "- z direction has open boundary" << std::endl;
    }
    else
    {
        std::cout << "Error: z direction has wrong boundary" << std::endl;
        exit(1);
    }

    if (transport_direction == 0)
    {
        std::cout << "- transport in x direction" << std::endl;
    }
    else if (transport_direction == 1)
    {
        std::cout << "- transport in y direction" << std::endl;
    }
    else if (transport_direction == 2)
    {
        std::cout << "- transport in z direction" << std::endl;
    }
    else 
    {
        std::cout << "Error: wrong transport direction" << std::endl;
        exit(1);
    }

    if (pbc[transport_direction] != 1)
    {
        std::cout << "Error: transport direction must be periodic" << std::endl;
        exit(1);
    }

    input >> lattice_constant[0] >> lattice_constant[1] >> lattice_constant[2];

    std::cout << "- lattice constant in x direction = "
              << lattice_constant[0] << std::endl;
    if (lattice_constant[0] <= 0) 
    {
        std::cout << "Error: lattice constant in x direction < 0" << std::endl;
        exit(1);
    }

    std::cout << "- lattice constant in y direction = "
              << lattice_constant[1] << std::endl;
    if (lattice_constant[1] <= 0) 
    {
        std::cout << "Error: lattice constant in y direction < 0" << std::endl;
        exit(1);
    }

    std::cout << "- lattice constant in z direction = "
              << lattice_constant[2] << std::endl;
    if (lattice_constant[2] <= 0) 
    {
        std::cout << "Error: lattice constant in z direction < 0" << std::endl;
        exit(1);
    }

    for (int d = 0; d < 3; ++d)
        box_length[d] = lattice_constant[d] * N_cell[d];
    volume = box_length[0] * box_length[1] * box_length[2];

    input >> N_orbital >> max_neighbor;
    std::cout << "- number of orbitals per cell = " << N_orbital << std::endl;
    if (N_orbital <= 0)
    {
        std::cout << "Error: number of orbitals per cell should > 0";
        exit(1);
    }

    std::cout << "- maximum number of hoppings per orbital = " << max_neighbor
              << std::endl;
    if (max_neighbor <= 0)
    {
        std::cout << "Error: maximum number of hoppings per orbital should > 0";
        exit(1);
    }

    number_of_atoms = N_orbital * N_cell[0] * N_cell[1] * N_cell[2];
    std::cout << "- total number of orbitals = "
              << number_of_atoms << std::endl;

    number_of_pairs = number_of_atoms * max_neighbor;
    neighbor_number = new int[number_of_atoms];
    neighbor_list = new int [number_of_pairs];
    hopping_real = new real[number_of_pairs];
    hopping_imag = new real[number_of_pairs];
    xx = new real[number_of_pairs];
    potential = new real[number_of_atoms];
    for (int n = 0; n < number_of_atoms; ++n)
    {
        potential[n] = 0.0;
    }

    // currently, I only need the positions in this case
    if (has_charged_impurities)
    {
        x.resize(number_of_atoms);
        y.resize(number_of_atoms);
        z.resize(number_of_atoms);
    }

    std::vector<real> x_cell, y_cell, z_cell;
    x_cell.resize(N_orbital);
    y_cell.resize(N_orbital);
    z_cell.resize(N_orbital);
    int number_of_hoppings_per_cell = N_orbital * max_neighbor;
    std::vector<std::vector<int>> hopping_data;
    hopping_data.assign(6, std::vector<int>(number_of_hoppings_per_cell, 0));

    std::cout << std::endl << "\torbital\tx\ty\tz" << std::endl;
    for (int n = 0; n < N_orbital; ++n)
    {
        input >> x_cell[n] >> y_cell[n] >> z_cell[n];
        std::cout << "\t" << n << "\t" << x_cell[n]
                               << "\t" << y_cell[n]
                               << "\t" << z_cell[n]
                               << std::endl;
    }

    std::vector<int> number_of_hoppings;
    number_of_hoppings.resize(N_orbital);
    for (int m = 0; m < N_orbital; m++)
    {
        input >> number_of_hoppings[m];
        std::cout << std::endl << "- number of hoppings for orbital " << m
                  << " = " << number_of_hoppings[m] << std::endl;

        for (int n = 0; n < number_of_hoppings[m]; ++n)
        {
            int nx, ny, nz, m_neighbor;
            real hopping_real, hopping_imag;
            input >> nx >> ny >> nz >> m_neighbor >> hopping_real
                  >> hopping_imag;

            hopping_data[0][m*max_neighbor+n] = nx;
            hopping_data[1][m*max_neighbor+n] = ny;
            hopping_data[2][m*max_neighbor+n] = nz;
            hopping_data[3][m*max_neighbor+n] = m_neighbor;
            hopping_data[4][m*max_neighbor+n] = hopping_real;
            hopping_data[5][m*max_neighbor+n] = hopping_imag;

            std::cout << "\tH(0,0,0," << m << "; " 
                 << nx << "," << ny << "," << nz << "," << m_neighbor << ") = "
                 << hopping_real << " + i " << hopping_imag << std::endl;
        }
    }

    for (int nx1 = 0; nx1 < N_cell[0]; ++nx1)
    {
        for (int ny1 = 0; ny1 < N_cell[1]; ++ny1)
        {
            for (int nz1 = 0; nz1 < N_cell[2]; ++nz1)
            {
                for (int m = 0; m < N_orbital; ++m)
                {
                    int n1 = find_index
                    (
                        nx1, ny1, nz1, N_cell[0], N_cell[1], N_cell[2], 
                        m, N_orbital
                    );

                    // currently, I only need the positions in this case
                    if (has_charged_impurities)
                    {
                        x[n1] = x_cell[m] + lattice_constant[0] * nx1;
                        y[n1] = y_cell[m] + lattice_constant[1] * ny1;
                        z[n1] = z_cell[m] + lattice_constant[2] * nz1;
                    }

                    int count = 0;
                    for (int i = 0; i < number_of_hoppings[m]; ++i)
                    {
                        int neighbor_index = n1 * max_neighbor + count;
                        int k = m*max_neighbor+i;

                        int nx2 = hopping_data[0][k] + nx1;
                        int ny2 = hopping_data[1][k] + ny1;
                        int nz2 = hopping_data[2][k] + nz1;
                        bool skip_x = !pbc[0] && (nx2 < 0 || nx2 >= N_cell[0]);
                        bool skip_y = !pbc[1] && (ny2 < 0 || ny2 >= N_cell[1]);
                        bool skip_z = !pbc[2] && (nz2 < 0 || nz2 >= N_cell[2]);
                        if (skip_x || skip_y || skip_z) continue;

                        neighbor_list[neighbor_index] = find_index
                        (
                            nx2, ny2, nz2, N_cell[0], N_cell[1], N_cell[2], 
                            hopping_data[3][k], N_orbital
                        );

                        real x12 = lattice_constant[transport_direction]
                                 * hopping_data[transport_direction][k];
                        x12 += x_cell[hopping_data[3][k]] - x_cell[m];
                        xx[neighbor_index] = x12;

                        hopping_real[neighbor_index] = hopping_data[4][k];
                        hopping_imag[neighbor_index] = hopping_data[5][k];

                        ++count;
                    }
                    neighbor_number[n1] = count;
                }
            }
        }
    }

    if (has_vacancy_disorder)
    {
        add_vacancies();
    }

    if (has_anderson_disorder)
    {
        add_anderson_disorder();
    }

    if (has_charged_impurities)
    {
        add_charged_impurities();
    }

    print_finished_reading(filename);
}



