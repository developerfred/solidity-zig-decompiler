FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV ZIG_VERSION=0.15.2

RUN apt-get update && apt-get install -y \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN curl -L https://ziglang.org/download/zig-linux-x86_64-${ZIG_VERSION}.tar.xz | tar -xJ && \
    mv zig-linux-x86_64-${ZIG_VERSION} /opt/zig && \
    ln -s /opt/zig/zig /usr/local/bin/zig && \
    rm -rf /tmp/*

WORKDIR /app

COPY . .

RUN zig build

ENTRYPOINT ["zig", "build", "run", "--"]
CMD ["--help"]
