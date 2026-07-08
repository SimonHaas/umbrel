#!/usr/bin/env bash
set -euo pipefail

arch="${1:-amd64}"
platform_arch="$arch"
if [[ "$arch" == "pi" ]]; then
    platform_arch="arm64"
fi

mkdir -p build

echo "Building usb-installer image for ${arch}..."
docker buildx build --load -f usb-installer.Dockerfile \
    --build-arg ARCH="${arch}" \
    --platform linux/${platform_arch} \
    --cache-from type=gha,scope=usb-installer-${arch} \
    --cache-to type=gha,mode=max,scope=usb-installer-${arch} \
    -t usb-installer:${arch} ../

echo "Exporting rootfs..."
container_id=$(docker run --platform linux/${platform_arch} -d usb-installer:${arch} /bin/true)
docker export -o build/rootfs-${arch}.tar "${container_id}"
docker rm "${container_id}"

echo "Building builder image for ${arch}..."
docker buildx build --load -f builder.Dockerfile \
    --platform linux/${platform_arch} \
    --cache-from type=gha,scope=usb-installer-builder-${arch} \
    --cache-to type=gha,mode=max,scope=usb-installer-builder-${arch} \
    -t usb-installer:builder-${arch} .

echo "Creating ISO image..."
docker run \
    --platform linux/${platform_arch} \
    --entrypoint /data/build.sh \
    -v "${PWD}":/data \
    --privileged \
    -e ARCH="${arch}" \
    usb-installer:builder-${arch}

# Test CD-ROM boot (used by VMs)
# qemu-system-x86_64 -net nic -net user -machine accel=tcg -m 2048 -bios ~/Downloads/OVMF.bin -cdrom umbrelos-amd64-usb-installer.iso
# qemu-system-aarch64 -net nic -net user -machine virt,accel=tcg -m 2048 -bios ~/Downloads/QEMU_EFI.fd -cdrom umbrelos-arm64-usb-installer.iso

# Test USB boot (used by physical machines)
# qemu-system-x86_64 -net nic -net user -machine accel=tcg -m 2048 -bios ~/Downloads/OVMF.bin -drive if=none,id=stick,format=raw,file=umbrelos-amd64-usb-installer.iso -device nec-usb-xhci,id=xhci -device usb-storage,bus=xhci.0,drive=stick
# qemu-system-aarch64 -net nic -net user -machine virt,accel=tcg -m 2048 -bios ~/Downloads/QEMU_EFI.fd -drive if=none,id=stick,format=raw,file=umbrelos-arm64-usb-installer.iso -device nec-usb-xhci,id=xhci -device usb-storage,bus=xhci.0,drive=stick