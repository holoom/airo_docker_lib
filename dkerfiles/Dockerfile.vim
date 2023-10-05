FROM osrf/ubuntu_arm64:focal
ENV DEBIAN_FRONTEND=noninteractive
ARG HOME=/root

# Pre-requisite
RUN sudo apt-get update && sudo apt-get -y upgrade 
RUN sudo apt-get -y install tmux curl wget curl net-tools git nano
RUN sudo touch /ros_entrypoint.sh

# ROS
RUN apt-get update
RUN sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'
RUN curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add -
RUN apt update && \
    apt-get -y install ros-noetic-desktop-full 
RUN echo "source /opt/ros/noetic/setup.bash" >> ~/.bashrc

# mavros
RUN sudo apt-get -y install ros-noetic-mavros ros-noetic-mavros-extras ros-noetic-mavros-msgs libncurses5-dev python3-pip libgstreamer1.0-dev python-jinja2 python3-pip python3-testresources libignition-math4 libgazebo11-dev
RUN sudo apt-get -y upgrade libignition-math4
RUN wget https://raw.githubusercontent.com/mavlink/mavros/master/mavros/scripts/install_geographiclib_datasets.sh
RUN sudo bash ./install_geographiclib_datasets.sh

# SSH
RUN sudo apt-get update
RUN sudo apt-get -y install openssh-server
# RUN echo -e "0000\n0000" | passwd root
RUN sudo echo "PermitRootLogin Yes" >> /etc/ssh/sshd_config
RUN sed -i 's/\(^Port\)/#\1/' /etc/ssh/sshd_config && echo Port 6666 >> /etc/ssh/sshd_config
RUN sed -i '4i\service ssh start' /ros_entrypoint.sh 

# NGROK
WORKDIR /
RUN curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null && echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list && sudo apt update && sudo apt install ngrok
RUN touch ngrok.sh
RUN echo "cd /usr/local/bin">> /ngrok.sh
RUN echo "./ngrok tcp 6666">> /ngrok.sh
RUN chmod +x ngrok.sh

# GIT Update
RUN sudo apt install software-properties-common -y
RUN sudo add-apt-repository -y ppa:git-core/ppa
RUN sudo apt update
RUN sudo apt install git -y

# FLVIS
WORKDIR $HOME
RUN apt update
RUN sudo apt-get install libsuitesparse-dev -y
RUN mkdir -p catkin_ws/src && cd ~/catkin_ws/src && \
    git clone -b noetic https://github.com/HKPolyU-UAV/FLVIS.git && \
    cd ~/catkin_ws/src/FLVIS/3rdPartLib && \
    sudo ./install3rdPartLib.sh

RUN /bin/bash -c '. /opt/ros/noetic/setup.bash; cd ~/catkin_ws/;\
    catkin_make'

RUN echo "source ~/catkin_ws/devel/setup.bash" >> ~/.bashrc

# AIRo_Control_Interface

WORKDIR $HOME
RUN git clone https://github.com/acados/acados.git && \
    cd ~/acados && git checkout 568e46c && \
    git submodule update --recursive --init && \
    mkdir build && cd build && \
    cmake -DACADOS_WITH_QPOASES=ON -DACADOS_WITH_OSQP=OFF/ON -DACADOS_INSTALL_DIR=~/acados .. && \
    sudo make install -j4

RUN mkdir -p ~/airo_control_interface_ws/src && \
    cd ~/airo_control_interface_ws/src && \
    git clone https://github.com/HKPolyU-UAV/airo_control_interface.git

RUN /bin/bash -c '. /opt/ros/noetic/setup.bash; cd ~/airo_control_interface_ws/;\
    catkin_make'
RUN echo "source ~/airo_control_interface_ws/devel/setup.bash" >> ~/.bashrc

RUN sudo apt-get install software-properties-common -y

RUN sudo add-apt-repository ppa:deadsnakes/ppa && sudo apt update && sudo apt install python3.7 -y && \
    python3 -m pip install pip && sudo pip3 install numpy matplotlib scipy future-fstrings casadi>=3.5.1 setuptools && \
    sudo apt-get install python3.7-tk -y && pip install -e ~/acados/interfaces/acados_template && \
    echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:"/root/acados/lib"' >> ~/.bashrc && \
    echo 'export ACADOS_SOURCE_DIR="/root/acados"' >> ~/.bashrc
RUN sudo apt install tmuxinator -y

# AIRo_Trajectory

WORKDIR $HOME
RUN mkdir -p ~/airo_trajectory_ws/src && \
    cd ~/airo_trajectory_ws/src && git clone https://github.com/HKPolyU-UAV/airo_trajectory.git && \
    cd ~/airo_trajectory_ws
RUN /bin/bash -c '. /opt/ros/noetic/setup.bash;. ~/airo_control_interface_ws/devel/setup.bash; cd ~/airo_trajectory_ws/;\
    catkin_make'
RUN echo "source ~/airo_trajectory_ws/devel/setup.bash" >> ~/.bashrc