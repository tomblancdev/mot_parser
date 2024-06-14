FROM debian:latest as builder

ARG USER=user
ARG USER_GROUP=user
ARG USER_SHELL=/bin/zsh
ARG USER_PASSWORD
ARG USER_SUDO=false
ARG UID=1000
ARG GID=1000

# Set environment variables
ENV ZSH_THEME=agnoster
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

# Check if user is root
RUN if [ $(id -u) -eq 0 || ${USER} = "root" ]; then echo "Please do not run this container as root"; exit 1; fi

RUN apt update && apt upgrade -y && apt install -y \
    git \
    zsh \
    sudo \
    curl \
    locales \
    locales-all \
    build-essential \
    mingw-w64
# Create user
RUN groupadd -g ${GID} ${USER_GROUP} && \
    useradd -m -u ${UID} -g ${GID} -s ${USER_SHELL} ${USER} && \
    usermod -aG sudo ${USER} && \
    echo "${USER}:${USER_PASSWORD}" | chpasswd

# Enable sudo
RUN if [ ${USER_SUDO} = "true" ]; then usermod -aG sudo ${USER}; fi

# Install Oh My Zsh for root and user
RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    && sed -i "s/robbyrussell/"'$ZSH_THEME'"/g" /root/.zshrc;

USER ${USER}
# set the default shell for the user to zsh if the user is not root
RUN if [ $USER != "root" ]; \
    then \
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && \
    sed -i "s/robbyrussell/"'$ZSH_THEME'"/g" /home/$USER/.zshrc; \
    fi

USER root
# Set zsh as default shell for root
RUN chsh -s $(which zsh) 
# Set zsh as default shell for user
RUN chsh -s $(which zsh) ${USER}

FROM builder as development
USER root

# Set Arguments
ARG WORKSPACE=/workspace

# Create workspace folder and set permissions
RUN mkdir -p ${WORKSPACE} && \
    chown -R ${USER}:${USER_GROUP} ${WORKSPACE} && \
    chmod -R 775 ${WORKSPACE}

USER ${USER}
WORKDIR ${WORKSPACE}

# install nim for user
RUN curl https://nim-lang.org/choosenim/init.sh -sSf | sh -s -- -y
# add nim to path
ENV PATH="/home/${USER}/.nimble/bin:${PATH}"

# Set WORKSPACE as safe directory if git is installed
RUN if [ -x "$(command -v git)" ]; then git config --global --add safe.directory ${WORKSPACE}; fi

# Run a long-lived process
CMD tail -f /dev/null