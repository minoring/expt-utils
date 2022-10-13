FROM ubuntu:20.04

# Use bash as a default shell.
SHELL ["/bin/bash", "-c"]

# Install common.
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y vim bzip2 wget ssh unzip git iproute2 iputils-ping build-essential curl \
    cmake ca-certificates libglib2.0-0 libxext6 libsm6 libxrender1 libspdlog-dev libeigen3-dev libopenblas-dev

# Install miniconda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh \
    && /bin/bash ~/miniconda.sh -b -p /opt/conda \
    && rm ~/miniconda.sh \
    && ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh \
    && echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc

# Install Polymetis.
ARG PYTHON_VERSION=3.8
ARG VENV_NAME=client
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    # Add robopkg
    && apt install -qqy lsb-release gnupg2 \
    && echo "deb [arch=amd64] http://robotpkg.openrobots.org/packages/debian/pub $(lsb_release -cs) robotpkg" | tee /etc/apt/sources.list.d/robotpkg.list \
    && curl http://robotpkg.openrobots.org/packages/debian/robotpkg.key | apt-key add - \
    && apt-get update \
    && apt install -qqy robotpkg-py38-pinocchio \
    && apt-get install -y libpoco-dev libspdlog-dev libeigen3-dev
RUN git clone --recursive https://github.com/minoring/fairo.git --branch furniture \
    && cd /fairo/polymetis \
    && /opt/conda/bin/conda env create -f ./polymetis/environment.yml -n ${VENV_NAME} python=${PYTHON_VERSION} \
    && echo "conda activate ${VENV_NAME}" >> ~/.bashrc

# Installation of robot learning framework
RUN apt-get update \
    # Install mujoco
    && mkdir /root/.mujoco \
    && wget https://github.com/deepmind/mujoco/releases/download/2.1.0/mujoco210-linux-x86_64.tar.gz -O /root/.mujoco/mujoco210_linux.tar.gz \
    && tar -xvzf /root/.mujoco/mujoco210_linux.tar.gz -C /root/.mujoco/ \
    && rm /root/.mujoco/mujoco210_linux.tar.gz \
    # download MuJoCo 2.1.1 for dm_control
    && wget https://github.com/deepmind/mujoco/releases/download/2.1.1/mujoco-2.1.1-linux-x86_64.tar.gz -O /root/.mujoco/mujoco211_linux.tar.gz \
    && tar -xvzf /root/.mujoco/mujoco211_linux.tar.gz -C /root/.mujoco/ \
    && rm /root/.mujoco/mujoco211_linux.tar.gz \
    # add MuJoCo 2.1.0 to LD_LIBRARY_PATH
    && echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/root/.mujoco/mujoco210/bin" >> ~/.bashrc \
    # for GPU rendering
    && echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib/nvidia" >> ~/.bashrc \
    && apt-get install -y cmake libopenmpi-dev libgl1-mesa-dev libgl1-mesa-glx libosmesa6-dev patchelf libglew-dev \
    # software rendering
    && apt-get install -y libgl1-mesa-glx libosmesa6 patchelf \
    # window rendering
    && apt-get install -y libglfw3 libglew-dev \
    && export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/root/.mujoco/mujoco210/bin \
    && export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib/nvidia \
    && /opt/conda/envs/${VENV_NAME}/bin/pip install install mujoco_py \
    # trigger mujoco to compile
	&& /opt/conda/envs/${VENV_NAME}/bin/python -c "import mujoco_py"

# Install pyrealsense2 and dt-apriltags.
RUN apt update \
    && apt install -y libcanberra-gtk-module libcanberra-gtk3-module libusb-1.0-0-dev \
    && /opt/conda/envs/${VENV_NAME}/bin/pip install pyrealsense2
RUN mkdir /wheels
COPY wheels/dt_apriltags-3.2.0-py3-none-manylinux2010_x86_64.whl /wheels
RUN /opt/conda/envs/${VENV_NAME}/bin/pip install /wheels/dt_apriltags-3.2.0-py3-none-manylinux2010_x86_64.whl
    # && git clone https://github.com/minoring/lib-dt-apriltags.git \
    # && cd lib-dt-apriltags \
    # && git submodule init \
    # && git submodule update \
    # && make build PYTHON_VERSION=3 \
    # && cd dist \
    # && /opt/conda/envs/${VENV_NAME}/bin/pip install dt_apriltags-3.2.0-py3-none-manylinux2010_x86_64.whl

# Install python packages.
RUN /opt/conda/envs/${VENV_NAME}/bin/pip install --ignore-installed gym==0.21.0 \
	h5py==3.6.0 opencv-python==4.1.2.30 pyquaternion ipdb numba

# Install keyboard
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y kmod kbd \
    && /opt/conda/envs/${VENV_NAME}/bin/pip install keyboard

# Setup Oculus
RUN apt update && apt install -y android-tools-adb \
    && curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash \
    && apt-get install git-lfs \
    && git lfs install \
    && git clone https://github.com/rail-berkeley/oculus_reader.git \
    && cd oculus_reader \
    && /opt/conda/envs/${VENV_NAME}/bin/pip install -e .

# Install cudatoolkit and torchvision for robot learning.
RUN /opt/conda/condabin/conda install -n ${VENV_NAME} openblas-devel -c anaconda
RUN /opt/conda/envs/${VENV_NAME}/bin/pip install torch==1.10 torchvision --extra-index-url https://download.pytorch.org/whl/cpu

# Build Polymetis
SHELL ["/opt/conda/bin/conda", "run", "-n", "client", "/bin/bash", "-c"]
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
    && cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/conda/envs/client -DBUILD_FRANKA=ON -DBUILD_TESTS=OFF -DBUILD_DOCS=OFF \
    && make -j
SHELL ["/bin/bash", "-c"]

RUN /opt/conda/envs/${VENV_NAME}/bin/pip install --upgrade hydra-core

COPY rolf /rolf
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install libopenmpi-dev \
    && /opt/conda/envs/${VENV_NAME}/bin/pip uninstall mpi4py \
    && /opt/conda/condabin/conda install -n ${VENV_NAME} -c conda-forge mpi4py \
    && /opt/conda/condabin/conda install -n ${VENV_NAME} -c conda-forge openmpi=4.1.2 \
    && cd /rolf \
    && /opt/conda/envs/${VENV_NAME}/bin/pip install -e .

# R3M
RUN git clone https://github.com/facebookresearch/r3m.git \
    && cd r3m \
    && /opt/conda/envs/${VENV_NAME}/bin/pip install -e .
