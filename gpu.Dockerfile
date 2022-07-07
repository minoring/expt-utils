FROM nvidia/cuda:11.3.1-base-ubuntu20.04
ARG PYTORCH=cu113

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
	&& echo "if [ -f ~/.bashrc ]; then . ~/.bashrc fi" >> /.bash_profile

# fzf
RUN git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf \
	&& ~/.fzf/install

# Install miniconda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh \
    && /bin/bash ~/miniconda.sh -b -p /opt/conda \
    && rm ~/miniconda.sh \
    && ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh \
    && echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc

ARG PYTHON_VERSION=3.8
ARG VENV_NAME=py38
RUN /opt/conda/bin/conda create -n ${VENV_NAME} python=${PYTHON_VERSION} \
    && echo "conda activate ${VENV_NAME}" >> ~/.bashrc

# Install mujoco
RUN apt-get update \
    # Install mujoco
    && mkdir /root/.mujoco \
    && wget https://github.com/deepmind/mujoco/releases/download/2.1.0/mujoco210-linux-x86_64.tar.gz -O /root/.mujoco/mujoco210_linux.tar.gz \
    && tar -xvzf /root/.mujoco/mujoco210_linux.tar.gz -C /root/.mujoco/ \
    && rm /root/.mujoco/mujoco210_linux.tar.gz \
    # add MuJoCo 2.1.0 to LD_LIBRARY_PATH
    && echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/root/.mujoco/mujoco210/bin" >> ~/.bashrc \
    # for GPU rendering
    && echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib/nvidia" >> ~/.bashrc \
    && apt-get install -y cmake libglfw3 libglew-dev libopenmpi-dev libgl1-mesa-dev libgl1-mesa-glx libosmesa6-dev patchelf libglew-dev \
    && export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/root/.mujoco/mujoco210/bin \
    && export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib/nvidia \
    && /opt/conda/envs/${VENV_NAME}/bin/pip install install mujoco_py \
    # trigger mujoco to compile
	&& /opt/conda/envs/${VENV_NAME}/bin/python -c "import mujoco_py"

# Install python packages.
RUN /opt/conda/envs/${VENV_NAME}/bin/pip install gym==0.21.0 opencv-python==4.1.2.30 numba hydra-core

# RUN /opt/conda/condabin/conda install -n ${VENV_NAME}  openblas-devel -c anaconda
# RUN /opt/conda/envs/${VENV_NAME}/bin/pip install torch==1.10 torchvision --extra-index-url https://download.pytorch.org/whl/${PYTORCH}
RUN /opt/conda/condabin/conda install -n ${VENV_NAME} pytorch=1.10 torchvision -c pytorch

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install libopenmpi-dev \
    && /opt/conda/envs/${VENV_NAME}/bin/pip uninstall mpi4py \
    && /opt/conda/condabin/conda install -n ${VENV_NAME} -c conda-forge mpi4py \
    && /opt/conda/condabin/conda install -n ${VENV_NAME} -c conda-forge openmpi=4.1.2 \

RUN /opt/conda/condabin/conda install -n ${VENV_NAME} -c conda-forge gh

# RUN git clone https://github.com/rail-berkeley/d4rl.git \
# 	&& cd d4rl \
# 	&& /opt/conda/envs/${VENV_NAME}/bin/pip install -e .

RUN /opt/conda/envs/${VENV_NAME}/bin/pip install jax flax ml_collections optax
RUN /opt/conda/envs/${VENV_NAME}/bin/pip install --upgrade "jax[cuda]" -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html
