FROM ubuntu:20.04

# Use bash as a default shell.
SHELL ["/bin/bash", "-c"]

# Install misc.
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y vim bzip2 wget ssh unzip git iproute2 iputils-ping build-essential curl \
    cmake ca-certificates libglib2.0-0 libxext6 libsm6 libxrender1 tmux

# miniconda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh \
    && /bin/bash ~/miniconda.sh -b -p /opt/conda \
    && rm ~/miniconda.sh \
    && ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh \
    && echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc

# Install Polymetis.
ARG PYTHON_VERSION=3.8
ARG VENV_NAME=server
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    # Add robopkg
    && apt install -qqy lsb-release gnupg2 \
    && echo "deb [arch=amd64] http://robotpkg.openrobots.org/packages/debian/pub $(lsb_release -cs) robotpkg" | tee /etc/apt/sources.list.d/robotpkg.list \
    && curl http://robotpkg.openrobots.org/packages/debian/robotpkg.key | apt-key add - \
    && apt-get update \
    && apt install -qqy robotpkg-py38-pinocchio \
    && apt-get install -y libpoco-dev libspdlog-dev libeigen3-dev
# Cloning large repository: https://stackoverflow.com/questions/21277806/fatal-early-eof-fatal-index-pack-failed
RUN git clone --recursive https://github.com/minoring/fairo.git --branch furniture \
    && cd /fairo/polymetis \
    && /opt/conda/bin/conda env create -f ./polymetis/environment.yml -n ${VENV_NAME} python=${PYTHON_VERSION} \
    && echo "conda activate ${VENV_NAME}" >> ~/.bashrc
RUN /opt/conda/condabin/conda install -n ${VENV_NAME} pytorch=1.10 cpuonly -c conda-forge -c pytorch

SHELL ["/opt/conda/bin/conda", "run", "-n", "server", "/bin/bash", "-c"]
RUN cd fairo/polymetis \
    # Add pinnochio path.
    && export PATH=/opt/openrobots/bin:$PATH \
    && export PKG_CONFIG_PATH=/opt/openrobots/lib/pkgconfig:$PKG_CONFIG_PATH \
    && export LD_LIBRARY_PATH=/opt/openrobots/lib:$LD_LIBRARY_PATH \
    && export PYTHONPATH=/opt/openrobots/lib/python3.8/site-packages:$PYTHONPATH \
    && export CMAKE_PREFIX_PATH=/opt/openrobots:$CMAKE_PREFIX_PATH \
    && /opt/conda/envs/${VENV_NAME}/bin/pip install -e ./polymetis \
    && cd /fairo \
    && git submodule update --init --recursive \
    && cd /fairo/polymetis/polymetis/src/clients/franka_panda_client/third_party/libfranka \
    && git checkout 0.9.0 \
    && git submodule update \
    && mkdir ./build \
    && cd ./build \
    && cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTS=OFF -DBUILD_EXAMPLES=OFF .. \
    && cmake --build . \
    && cd /fairo \
    && mkdir -p ./polymetis/polymetis/build \
    && cd ./polymetis/polymetis/build \
    && cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/conda/envs/server -DBUILD_FRANKA=ON -DBUILD_TESTS=OFF -DBUILD_DOCS=OFF \
    && make -j
SHELL ["/bin/bash", "-c"]
