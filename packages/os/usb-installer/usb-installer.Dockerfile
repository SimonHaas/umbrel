FROM debian:bookworm-slim

ARG ARCH=amd64

RUN echo "root:root" | chpasswd

RUN apt-get -y update

# Install Linux kernel, systemd, bootloader and script deps
RUN if [ "$ARCH" = "amd64" ]; then \
        apt-get install --yes --no-install-recommends linux-image-amd64 systemd-sysv xz-utils dmidecode; \
    elif [ "$ARCH" = "arm64" ]; then \
        apt-get install --yes --no-install-recommends linux-image-arm64 systemd-sysv xz-utils dmidecode; \
    else \
        echo "Unsupported architecture: $ARCH"; exit 1; \
    fi

# Reduce size
# We have to do this extremely aggreseively because we're close to GitHub's 2GB release asset limit
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /usr/share/man /usr/share/doc /usr/share/info /var/log/*
RUN find / -name '*.a' -delete && \
    find / -name '*.so*' -exec strip --strip-debug {} \;

# Remove architecture-specific modules
RUN if [ "$ARCH" = "amd64" ]; then \
        rm -rf /usr/lib/modules/*/kernel/drivers/gpu; \
        rm -rf /usr/lib/modules/*/kernel/drivers/net; \
        rm -rf /usr/lib/modules/*/kernel/drivers/infiniband; \
        rm -rf /usr/lib/modules/*/kernel/net; \
        rm -rf /usr/lib/modules/*/kernel/sound; \
    elif [ "$ARCH" = "arm64" ]; then \
        rm -rf /usr/lib/modules/*/kernel/drivers/gpu; \
        rm -rf /usr/lib/modules/*/kernel/drivers/net; \
        rm -rf /usr/lib/modules/*/kernel/drivers/infiniband; \
        rm -rf /usr/lib/modules/*/kernel/net; \
        rm -rf /usr/lib/modules/*/kernel/sound; \
    fi

# Copy in umbrelOS image
COPY build/umbrelos-${ARCH}.img.xz  /umbrelos.img.xz

# Copy in filesystem overlay
COPY usb-installer/overlay /

# Configure TTY services
RUN systemctl enable custom-tty.service
RUN systemctl mask console-getty.service
RUN systemctl mask getty@tty1.service