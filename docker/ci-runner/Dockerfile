FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libboost-all-dev \
    python3 \
    python3-pip \
    python3-numpy \
    python3-mako \
    python3-requests \
    libgrpc++-dev \
    protobuf-compiler-grpc \
    libprotobuf-dev \
    libdpdk-dev \
    && rm -rf /var/lib/apt/lists/*
