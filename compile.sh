rm -r build
cmake -B build -DCMAKE_BUILD_TYPE=Release
make -C build -j$(nproc)