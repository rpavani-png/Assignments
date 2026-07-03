FROM ubuntu:22.04

RUN apt update && \
    apt install -y openssh-server sudo python3 docker.io

RUN mkdir /var/run/sshd


# create ansible user
RUN useradd -m ansible

RUN echo "ansible:password" | chpasswd


# allow sudo without password
RUN echo "ansible ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers


EXPOSE 22


CMD ["/usr/sbin/sshd","-D"]