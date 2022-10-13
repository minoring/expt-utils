FROM nvidia/cuda:11.3.1-devel-ubuntu20.04

# Use bash as a default shell.
SHELL ["/bin/bash", "-c"]

# Remove any third-party apt sources to avoid issues with expiring keys.
RUN rm -f /etc/apt/sources.list.d/*.list

# Install common.
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y vim bzip2 wget ssh unzip git build-essential curl \
    cmake ca-certificates libglib2.0-0 libxext6 libsm6 libxrender1 tmux

# Run bash.rc when ssh connected.
RUN touch "/.bash_profile" \
	&& echo "if [ -f /root/.bashrc ]; then . /root/.bashrc fi" >> /.bash_profile

# fzf
RUN git clone --depth 1 https://github.com/junegunn/fzf.git /.fzf \
	&& /.fzf/install

# Install miniconda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh \
    && /bin/bash ~/miniconda.sh -b -p /opt/conda \
    && rm ~/miniconda.sh \
    && ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh \
    && echo ". /opt/conda/etc/profile.d/conda.sh" >> /root/.bashrc

ARG PYTHON_VERSION=3.8
ARG VENV_NAME=py38
RUN /opt/conda/bin/conda create -n ${VENV_NAME} python=${PYTHON_VERSION} \
    && echo "conda activate ${VENV_NAME}" >> /root/.bashrc

# Install mujoco
RUN apt-get update \
    # Install mujoco
    && mkdir /root/.mujoco \
    && wget https://github.com/deepmind/mujoco/releases/download/2.1.0/mujoco210-linux-x86_64.tar.gz -O /root/.mujoco/mujoco210_linux.tar.gz \
    && tar -xvzf /root/.mujoco/mujoco210_linux.tar.gz -C /root/.mujoco/ \
    && rm /root/.mujoco/mujoco210_linux.tar.gz \
    # add MuJoCo 2.1.0 to LD_LIBRARY_PATH
    && echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/root/.mujoco/mujoco210/bin" >> /root/.bashrc \
    # for GPU rendering
    && echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib/nvidia" >> /root/.bashrc \
    && apt-get install -y cmake libglfw3 libglew-dev libopenmpi-dev libgl1-mesa-dev libgl1-mesa-glx libosmesa6-dev patchelf libglew-dev \
    && export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/root/.mujoco/mujoco210/bin \
    && export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib/nvidia \
    && /opt/conda/envs/${VENV_NAME}/bin/pip install install mujoco_py \
    # trigger mujoco to compile
	&& /opt/conda/envs/${VENV_NAME}/bin/python -c "import mujoco_py"

# Install python packages.
RUN /opt/conda/envs/${VENV_NAME}/bin/pip install numpy==1.22 numba gym==0.21.0 opencv-python==4.1.2.30 hydra-core

RUN /opt/conda/condabin/conda install -n ${VENV_NAME}  openblas-devel -c anaconda
RUN /opt/conda/envs/${VENV_NAME}/bin/pip install torch==1.10 torchvision --extra-index-url https://download.pytorch.org/whl/${PYTORCH}
# RUN /opt/conda/condabin/conda install -n ${VENV_NAME} pytorch torchvision -c pytorch

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install libopenmpi-dev \
    && /opt/conda/envs/${VENV_NAME}/bin/pip uninstall mpi4py \
    && /opt/conda/condabin/conda install -n ${VENV_NAME} -c conda-forge mpi4py \
    && /opt/conda/condabin/conda install -n ${VENV_NAME} -c conda-forge openmpi=4.1.2 \
    && /opt/conda/condabin/conda install -n ${VENV_NAME} -c conda-forge gh

# RUN git clone https://github.com/rail-berkeley/d4rl.git \
# 	&& cd d4rl \
# 	&& /opt/conda/envs/${VENV_NAME}/bin/pip install -e .

# JAX
# RUN /opt/conda/envs/${VENV_NAME}/bin/pip install jax flax ml_collections optax tensorflow protobuf==3.20.*
# RUN /opt/conda/condabin/conda install -n ${VENV_NAME} -c anaconda cudnn=8.2.1 cudatoolkit=11.3
# RUN /opt/conda/envs/${VENV_NAME}/bin/pip install -U jax[cuda11_cudnn82] -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html
