FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    build-essential \
    openmpi-bin \
    libopenmpi-dev \
    make

WORKDIR /app

COPY . .

CMD ["/bin/bash"]