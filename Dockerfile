FROM ubuntu:22.04

# setting Timezone, Launguage
RUN apt update && \
  apt install -y --no-install-recommends locales sudo vi software-properties-common tzdata && \
  locale-gen en_US en_US.UTF-8 && \
  update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 && \
  add-apt-repository universe

ENV LANG en_US.UTF-8
ENV TZ=Asia/Tokyo

# Install ROS2
RUN apt update && \
  apt install -y --no-install-recommends && \
  curl gnupg2 lsb-release python3-pip vim wget build-essential ca-certificates

RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg && \
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null

RUN apt update && apt upgrade && DEBIAN_FRONTEND=noninteractive && \
  apt install -y --no-install-recommends ros-humble-desktop && \
  rm -rf /var/lib/apt/lists/*

RUN bash /opt/ros/humble/setup.sh 

# Install Nvidia Container Toollit
RUN distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
  && curl -s -L https://nvidia.github.io/libnvidia-container/gpgkey | apt-key add - \
  && curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

RUN apt-get update \
  && apt-get install -y --no-install-recommends nvidia-container-toolkit

# Add user and group
ARG UID
ARG GID
ARG USER_NAME
ARG GROUP_NAME

RUN groupadd -g ${GID} ${GROUP_NAME} && \
    useradd -u ${UID} -g ${GID} -s /bin/bash -m ${USER_NAME}

USER ${USER_NAME}

WORKDIR /home/${USER_NAME}

CMD ["/bin/bash"]

# Configuring ROS2