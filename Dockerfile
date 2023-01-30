FROM ubuntu:22.04 AS ubuntu-base

# setting Timezone, Launguage
RUN apt update && \
  apt install -y --no-install-recommends locales sudo vim software-properties-common tzdata && \
  locale-gen en_US en_US.UTF-8 && \
  update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 && \
  add-apt-repository universe

ENV LANG en_US.UTF-8
ENV TZ Asia/Tokyo

FROM ubuntu-base AS ros2-base

# Install ROS2
RUN apt update && \
  apt install -y --no-install-recommends \
  curl gnupg2 lsb-release python3-pip vim wget build-essential ca-certificates

RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg && \
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null

RUN apt update && apt upgrade -y && DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends ros-humble-desktop ros-dev-tools  && \
  rm -rf /var/lib/apt/lists/*

RUN bash /opt/ros/humble/setup.sh 

FROM ros2-base AS cuda-ros2-base

# Install Nvidia Container Toollit
RUN distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
  && curl -s -L https://nvidia.github.io/libnvidia-container/gpgkey | apt-key add - \
  && curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

RUN apt-get update \
  && apt-get install -y --no-install-recommends nvidia-container-toolkit

# Add user and group
ARG UID && GID && USER_NAME && GROUP_NAME 
ARG PASSWD=${USER_NAME}

RUN groupadd -g ${GID} ${GROUP_NAME} && \
    useradd -m -s /bin/bash -u $UID -g ${GID} -G sudo ${USER_NAME} && \
    echo ${USER_NAME}:${PASSWD} | chpasswd && \
    echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER ${USER_NAME}

WORKDIR /home/${USER_NAME}

# Configuring ROS2
FROM cuda-ros2-base AS cuda-ros2

ARG ROS_DOMAIN_ID=${ROS_DOMAIN_ID} && ROS_LOCALHOST_ONLY=${ROS_LOCALHOST_ONLY}

ENV ROS_DOMAIN_ID ${ROS_DOMAIN_ID}
ENV ROS_LOCALHOST_ONLY ${ROS_LOCALHOST_ONLY}

# Configuring python environment
FROM cuda-ros2 AS cuda-ros2-python-base

# Installing python
ARG USER_NAME=${USER_NAME}

ENV HOME /home/${USER_NAME}
ENV POETRY_VERSION 1.3.1
ENV POETRY_PATH ${HOME}
ENV PATH $PATH:$HOME/.poetry/bin:$HOME/.local/bin:$HOME/bin:$PATH

WORKDIR ${HOME}/app
RUN sudo chown -R ${USER_NAME} ${HOME}  && sudo chmod -R 777 ${HOME}
USER ${USER_NAME}

RUN sudo apt install --no-install-recommends -y python3.10 python3-pip python3.10-dev \
    python3-setuptools python3-distutils curl &&\
    sudo update-alternatives --install /usr/local/bin/python python /usr/bin/python3.10 1 && \
    sudo pip install --upgrade pip

COPY ./pyproject.toml ${HOME}/app 
COPY ./poetry.lock ${HOME}/app

### install packages
RUN curl -sSL https://install.python-poetry.org | POETRY_VERSION=$POETRY_VERSION python -  && \
    poetry config virtualenvs.create false && \
    poetry export -f requirements.txt --output requirements.txt --without-hashes && \
    pip3 install -r requirements.txt --user --no-deps

# Configure robo trade codes
FROM cuda-ros2-python-base AS robo-trade

ARG USER_NAME=${USER_NAME}
RUN sudo chown -R ${USER_NAME} ${HOME}  && sudo chmod -R 777 ${HOME}

USER ${USER_NAME}

WORKDIR ${HOME}/app

# initialize ROS
RUN sudo rosdep init && rosdep update


CMD ["/bin/bash"]
