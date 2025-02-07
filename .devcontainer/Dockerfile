FROM centos:7

RUN yum -y update && \
    yum install gcc gcc-c++ glibc-static -y 

RUN yum -y install wget

RUN yum -y install git

RUN yum -y install python3

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain 1.83.0

ENV PATH="/root/.cargo/bin:${PATH}"

RUN yum -y install java-1.8.0-openjdk-devel

RUN wget https://repo.huaweicloud.com/apache/maven/maven-3/3.9.6/binaries/apache-maven-3.9.6-bin.tar.gz && \
    tar -xzf apache-maven-*.tar.gz && \
    mkdir -p /opt/maven && \
    mv apache-maven-* /opt/maven && \
    ln -s /opt/maven/apache-maven-3.9.6/bin/mvn /usr/bin/mvn

CMD ["tail", "-f", "/dev/null"]
