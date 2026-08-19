#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================
# WINDOWS SERVER 2022
# DOCKER + KVM + TAILSCALE + WEB VNC + RDP
#
# CPU      : MAX
# RAM      : AUTO / MAX 10G
# DISK     : 20G QCOW2
#
# VNC      : 8006
# RDP      : 3389
#
# CLEAR_WINDOWS:
#   ON  = XÓA WINDOWS + STORAGE + DOCKUR CACHE + DOCKER CACHE
#   OFF = GIỮ NGUYÊN DỮ LIỆU
#
# FORCE_REINSTALL:
#   ON  = CLEAR + CÀI MỚI
#   OFF = KHÔNG REINSTALL
#
# TAILSCALE:
#   LUÔN ÉP LOGOUT + LOGIN BẰNG AUTH KEY
#
# NOVNC:
#   CLIP TO WINDOW     = ON
#   SCALING MODE       = ON
#   HIDE CLIP SETTING  = ON
#   HIDE SCALE SETTING = ON
#
# ALLOCATE:
#   KHÔNG CÒN TRONG SCRIPT
# ==============================================================


# ==============================================================
# BASIC
# ==============================================================

NAME="windows"
IMAGE="dockurr/windows:latest"
WINDOWS_VERSION="2022"

USERNAME="vanmangaming"
PASSWORD="@vanmangaming@2K@"


# ==============================================================
# TAILSCALE AUTH KEY
# ==============================================================
#
# DÁN AUTH KEY MỚI CỦA BẠN VÀO ĐÂY.
#
# Không dùng lại key đã bị lộ trước đó.
# ==============================================================

TS_AUTH_KEY="tskey-auth-kCreZecqck11CNTRL-eACAGgQwWBdLz4iCWhw1Cde4U5EQFHJi"


# ==============================================================
# CLEAR WINDOWS
# ==============================================================

CLEAR_WINDOWS="ON"
FORCE_REINSTALL="ON"


# ==============================================================
# WINDOWS IMAGE
# ==============================================================

REMOVE_WINDOWS_IMAGE="ON"


# ==============================================================
# AUTO RESTART
# ==============================================================

AUTO_RESTART="ON"


# ==============================================================
# WINDOWS FEATURES
# ==============================================================

KVM="ON"
HV="ON"
AUTOLOGIN="ON"
RAM_CHECK="ON"
WEB="ON"


# ==============================================================
# CPU
# ==============================================================

CPU_CORES="max"
CPU_MODEL="host"


# ==============================================================
# RAM
# ==============================================================

# AUTO:
#   Script tự tính RAM.
#
# FIXED:
#   Dùng RAM_SIZE.
# ==============================================================

RAM_MODE="AUTO"

# AUTO tối đa 10G
RAM_MAX_GB="10"

# AUTO tối thiểu 4G
RAM_MIN_GB="4"

# Chừa lại 1G cho host
RAM_RESERVE_GB="1"

# Chỉ dùng khi RAM_MODE=FIXED
RAM_SIZE="12G"


# ==============================================================
# DISK
# ==============================================================

DISK_SIZE="20G"
DISK_FMT="qcow2"


# ==============================================================
# STORAGE
# ==============================================================

STORAGE_VOLUME="windows-storage"


# ==============================================================
# DOCKUR CACHE
# ==============================================================

DOCKUR_WINDOWS_DIR="/home/codespace/windows"


# ==============================================================
# WINDOWS DISPLAY
# ==============================================================

WIDTH="1280"
HEIGHT="720"


# ==============================================================
# VNC
# ==============================================================

DISPLAY="web"
WEB_PORT="8006"
CONSOLE_PORT="8006"


# ==============================================================
# NOVNC
# ==============================================================

NOVNC_CLIP_TO_WINDOW="ON"
NOVNC_SCALING_MODE="ON"

NOVNC_HIDE_CLIP_SETTING="ON"
NOVNC_HIDE_SCALING_SETTING="ON"


# ==============================================================
# RDP
# ==============================================================

RDP_PORT="3389"


# ==============================================================
# HOST REQUIREMENTS
# ==============================================================

MIN_HOST_CPU=2
MIN_HOST_RAM_GB=15
MIN_HOST_FREE_DISK_GB=20


# ==============================================================
# WAIT
# ==============================================================

WINDOWS_BOOT_LOOPS=360
WINDOWS_BOOT_INTERVAL=5

VNC_WAIT_LOOPS=60
VNC_WAIT_INTERVAL=2

RDP_WAIT_LOOPS=90
RDP_WAIT_INTERVAL=2


# ==============================================================
# COLORS
# ==============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'


# ==============================================================
# OUTPUT
# ==============================================================

info() {
    echo -e "${BLUE}[INFO]${RESET} $*"
}

ok() {
    echo -e "${GREEN}[OK]${RESET} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${RESET} $*"
}

error() {
    echo -e "${RED}[ERROR]${RESET} $*" >&2
}

section() {
    echo
    echo -e "${CYAN}============================================================${RESET}"
    echo -e "${CYAN} $*${RESET}"
    echo -e "${CYAN}============================================================${RESET}"
    echo
}

die() {
    error "$*"
    exit 1
}


# ==============================================================
# FLAG -> Y/N
# ==============================================================

flag_to_yn() {

    case "$1" in
        ON)
            printf 'Y'
            ;;
        OFF)
            printf 'N'
            ;;
        *)
            return 1
            ;;
    esac
}


# ==============================================================
# VALIDATE FLAG
# ==============================================================

validate_flag() {

    local name="$1"
    local value="$2"

    [[ "$value" == "ON" ||
       "$value" == "OFF" ]] ||
        die "${name} chỉ được ON hoặc OFF."
}


# ==============================================================
# VALIDATE CONFIG
# ==============================================================

validate_config() {

    validate_flag "CLEAR_WINDOWS" "$CLEAR_WINDOWS"
    validate_flag "FORCE_REINSTALL" "$FORCE_REINSTALL"
    validate_flag "REMOVE_WINDOWS_IMAGE" "$REMOVE_WINDOWS_IMAGE"
    validate_flag "AUTO_RESTART" "$AUTO_RESTART"

    validate_flag "KVM" "$KVM"
    validate_flag "HV" "$HV"
    validate_flag "AUTOLOGIN" "$AUTOLOGIN"
    validate_flag "RAM_CHECK" "$RAM_CHECK"
    validate_flag "WEB" "$WEB"

    validate_flag "NOVNC_CLIP_TO_WINDOW" "$NOVNC_CLIP_TO_WINDOW"
    validate_flag "NOVNC_SCALING_MODE" "$NOVNC_SCALING_MODE"
    validate_flag "NOVNC_HIDE_CLIP_SETTING" "$NOVNC_HIDE_CLIP_SETTING"
    validate_flag "NOVNC_HIDE_SCALING_SETTING" "$NOVNC_HIDE_SCALING_SETTING"


    [[ "$CPU_CORES" == "max" ]] ||
        die "CPU_CORES phải là max."


    [[ "$RAM_MODE" == "AUTO" ||
       "$RAM_MODE" == "FIXED" ]] ||
        die "RAM_MODE chỉ được AUTO hoặc FIXED."


    [[ "$RAM_MAX_GB" =~ ^[0-9]+$ ]] ||
        die "RAM_MAX_GB không hợp lệ."


    [[ "$RAM_MIN_GB" =~ ^[0-9]+$ ]] ||
        die "RAM_MIN_GB không hợp lệ."


    [[ "$RAM_RESERVE_GB" =~ ^[0-9]+$ ]] ||
        die "RAM_RESERVE_GB không hợp lệ."


    (( RAM_MIN_GB <= RAM_MAX_GB )) ||
        die "RAM_MIN_GB không được lớn hơn RAM_MAX_GB."


    if [[ "$RAM_MODE" == "FIXED" ]]; then

        [[ "$RAM_SIZE" =~ ^[0-9]+G$ ]] ||
            die "RAM_SIZE phải dạng 8G, 10G, 12G..."
    fi


    [[ "$DISK_SIZE" == "20G" ]] ||
        die "DISK_SIZE phải là 20G."


    [[ "$DISK_FMT" == "qcow2" ]] ||
        die "DISK_FMT phải là qcow2."


    [[ -n "$TS_AUTH_KEY" ]] ||
        die "TS_AUTH_KEY đang trống."


    [[ "$TS_AUTH_KEY" != "PASTE_TAILSCALE_AUTH_KEY_HERE" ]] ||
        die "Bạn chưa nhập Auth Key Tailscale."


    [[ "$TS_AUTH_KEY" == tskey-* ]] ||
        die "TS_AUTH_KEY không đúng định dạng."
}


# ==============================================================
# HOST INFO
# ==============================================================

host_cpu() {
    nproc 2>/dev/null || echo 0
}


host_ram_gb() {
    free -g 2>/dev/null |
        awk '/^Mem:/ {print $2; exit}' ||
        echo 0
}


host_available_ram_gb() {
    free -g 2>/dev/null |
        awk '/^Mem:/ {print $7; exit}' ||
        echo 0
}


host_free_gb() {
    df -BG "$HOME" 2>/dev/null |
        awk 'NR==2 {
            gsub("G","",$4);
            print $4;
            exit
        }' ||
        echo 0
}


# ==============================================================
# RAM AUTO
# ==============================================================

calculate_ram() {

    if [[ "$RAM_MODE" == "FIXED" ]]; then

        EFFECTIVE_RAM_SIZE="$RAM_SIZE"

        return 0
    fi


    local available
    local calculated


    available="$(host_available_ram_gb)"


    if ! [[ "$available" =~ ^[0-9]+$ ]]; then
        available=0
    fi


    calculated=$((available - RAM_RESERVE_GB))


    if (( calculated < RAM_MIN_GB )); then
        calculated="$RAM_MIN_GB"
    fi


    if (( calculated > RAM_MAX_GB )); then
        calculated="$RAM_MAX_GB"
    fi


    EFFECTIVE_RAM_SIZE="${calculated}G"
}


# ==============================================================
# CONTAINER
# ==============================================================

container_exists() {

    docker inspect "$NAME" \
        >/dev/null 2>&1
}


container_running() {

    [[ "$(
        docker inspect \
            -f '{{.State.Running}}' \
            "$NAME" \
            2>/dev/null ||
            echo false
    )" == "true" ]]
}


container_status() {

    docker inspect \
        -f '{{.State.Status}}' \
        "$NAME" \
        2>/dev/null ||
        echo "missing"
}


container_exit_code() {

    docker inspect \
        -f '{{.State.ExitCode}}' \
        "$NAME" \
        2>/dev/null ||
        echo "unknown"
}


container_restart_count() {

    docker inspect \
        -f '{{.RestartCount}}' \
        "$NAME" \
        2>/dev/null ||
        echo "0"
}


container_restart_policy() {

    docker inspect \
        -f '{{.HostConfig.RestartPolicy.Name}}' \
        "$NAME" \
        2>/dev/null ||
        echo "unknown"
}


# ==============================================================
# VOLUME
# ==============================================================

volume_exists() {

    docker volume inspect \
        "$STORAGE_VOLUME" \
        >/dev/null 2>&1
}


volume_mountpoint() {

    docker volume inspect \
        -f '{{.Mountpoint}}' \
        "$STORAGE_VOLUME" \
        2>/dev/null ||
        true
}


volume_size() {

    if ! volume_exists; then

        echo "N/A"

        return
    fi


    local mountpoint

    mountpoint="$(volume_mountpoint)"


    if [[ -z "$mountpoint" ||
          ! -d "$mountpoint" ]]; then

        echo "N/A"

        return
    fi


    du -sh "$mountpoint" 2>/dev/null |
        awk '{print $1}' ||
        echo "N/A"
}


# ==============================================================
# PORT
# ==============================================================

check_port() {

    timeout 5 \
        bash -c "</dev/tcp/127.0.0.1/$1" \
        >/dev/null 2>&1
}


# ==============================================================
# LOG
# ==============================================================

last_logs() {

    docker logs \
        --tail 300 \
        "$NAME" \
        2>&1 ||
        true
}


# ==============================================================
# WINDOWS READY
# ==============================================================

windows_ready() {

    docker logs "$NAME" 2>&1 |
        grep -Eqi \
        'Windows started successfully|Windows started succesfully'
}


# ==============================================================
# WINDOWS DISK ERROR
# ==============================================================

windows_disk_error() {

    docker logs "$NAME" 2>&1 |
        tail -150 |
        grep -Eqi \
        'Not enough free space to create a disk|No space left on device|only .* GB available'
}


# ==============================================================
# SHOW CONTAINER STATE
# ==============================================================

show_container_state() {

    section "NO WINDOWS CONTAINER"


    if container_exists; then

        warn "Container ${NAME} đang tồn tại."


        echo
        echo "Status        : $(container_status)"
        echo "Exit code     : $(container_exit_code)"
        echo "Restart count : $(container_restart_count)"
        echo "Restart policy: $(container_restart_policy)"

    else

        ok "Chưa có container ${NAME}."
    fi
}


# ==============================================================
# TAILSCALE
# ==============================================================

prepare_tailscale() {

    section "TAILSCALE"


    if ! command -v tailscale >/dev/null 2>&1; then

        info "Tailscale chưa có."
        info "Installing Tailscale..."


        curl -fsSL \
            https://tailscale.com/install.sh |
            sudo sh >/dev/null 2>&1 ||
            die "Tailscale cài thất bại."


        ok "Tailscale đã cài."

    else

        ok "Tailscale đã có."
    fi


    sudo systemctl enable tailscaled \
        >/dev/null 2>&1 ||
        true


    sudo systemctl start tailscaled \
        >/dev/null 2>&1 ||
        true


    if ! pgrep -x tailscaled >/dev/null 2>&1; then

        info "Starting tailscaled..."


        sudo tailscaled \
            >/tmp/tailscaled.log \
            2>&1 &


        sleep 4
    fi


    info "Đang logout Tailscale hiện tại..."


    sudo tailscale logout \
        >/dev/null 2>&1 ||
        true


    sleep 2


    info "Đang đăng nhập bằng Auth Key..."


    sudo tailscale up \
        --auth-key="$TS_AUTH_KEY" \
        --hostname="windows-${CODESPACE_NAME:-codespace}" \
        --timeout=60s \
        >/dev/null 2>&1 ||
        die "Tailscale Auth Key đăng nhập thất bại."


    sleep 4


    local ip


    ip="$(
        sudo tailscale ip -4 \
            2>/dev/null |
        head -1 ||
        true
    )"


    [[ -n "$ip" ]] ||
        die "Không lấy được Tailscale IP."


    sudo tailscale set \
        --accept-dns=false \
        >/dev/null 2>&1 ||
        true


    TAILSCALE_IP="$ip"


    ok "Tailscale IP: ${TAILSCALE_IP}"


    echo

    info "Tailscale status:"


    sudo tailscale status \
        2>/dev/null |
        head -30 ||
        true
}


# ==============================================================
# HOST CHECK
# ==============================================================

check_prereqs() {

    section "HOST CHECK"


    command -v docker >/dev/null 2>&1 ||
        die "Docker chưa được cài."


    docker info >/dev/null 2>&1 ||
        die "Docker daemon không chạy."


    [[ -e /dev/kvm ]] ||
        die "/dev/kvm không tồn tại."


    if [[ ! -e /dev/net/tun ]]; then

        sudo mkdir -p /dev/net

        sudo modprobe tun \
            >/dev/null 2>&1 ||
            true
    fi


    [[ -e /dev/net/tun ]] ||
        die "/dev/net/tun không tồn tại."


    command -v curl >/dev/null 2>&1 ||
        die "curl chưa được cài."


    sudo -n true \
        >/dev/null 2>&1 ||
        sudo -v


    HOST_CPU="$(host_cpu)"
    HOST_RAM_GB="$(host_ram_gb)"
    HOST_AVAILABLE_RAM_GB="$(host_available_ram_gb)"
    HOST_FREE_GB="$(host_free_gb)"


    calculate_ram


    echo "Host CPU           : ${HOST_CPU} cores"
    echo "Host RAM           : ${HOST_RAM_GB} GB"
    echo "Host RAM available : ${HOST_AVAILABLE_RAM_GB} GB"
    echo "Host free disk     : ${HOST_FREE_GB} GB"

    echo


    (( HOST_CPU >= MIN_HOST_CPU )) ||
        die "Host cần ít nhất ${MIN_HOST_CPU} CPU."


    (( HOST_RAM_GB >= MIN_HOST_RAM_GB )) ||
        die "Host cần ít nhất ${MIN_HOST_RAM_GB} GB RAM."


    info "Storage backend : Docker named volume"
    info "Storage volume  : ${STORAGE_VOLUME}"
    info "Windows disk    : ${DISK_SIZE}"
    info "Disk format     : ${DISK_FMT}"
    info "RAM mode        : ${RAM_MODE}"
    info "RAM assigned    : ${EFFECTIVE_RAM_SIZE}"
    info "RAM max         : ${RAM_MAX_GB}G"


    if (( HOST_FREE_GB < MIN_HOST_FREE_DISK_GB )); then

        warn "Host chỉ còn ${HOST_FREE_GB} GB trống."
    fi


    ok "Host check passed."
}


# ==============================================================
# HOST CLEANUP
# ==============================================================

cleanup_host_space() {

    section "HOST CLEANUP"


    info "Dọn APT cache..."


    sudo apt-get clean \
        >/dev/null 2>&1 ||
        true


    sudo apt-get autoclean \
        >/dev/null 2>&1 ||
        true


    info "Dọn temporary files..."


    sudo find /tmp \
        -mindepth 1 \
        -maxdepth 1 \
        -exec rm -rf {} + \
        2>/dev/null ||
        true


    sudo find /var/tmp \
        -mindepth 1 \
        -maxdepth 1 \
        -exec rm -rf {} + \
        2>/dev/null ||
        true


    info "Dọn pip cache..."


    python3 -m pip cache purge \
        >/dev/null 2>&1 ||
        true


    info "Dọn npm cache..."


    npm cache clean \
        --force \
        >/dev/null 2>&1 ||
        true


    info "Dọn user cache..."


    rm -rf \
        "${HOME}/.cache/pip" \
        "${HOME}/.cache/npm" \
        "${HOME}/.cache/yarn" \
        "${HOME}/.cache/pnpm" \
        2>/dev/null ||
        true


    echo

    section "DISK AFTER HOST CLEANUP"

    df -h /
}


# ==============================================================
# DOCKUR CACHE
# ==============================================================

clear_dockur_cache() {

    section "DOCKUR CACHE CLEANUP"


    if [[ ! -d "$DOCKUR_WINDOWS_DIR" ]]; then

        info "Không có Dockur cache."

        return 0
    fi


    info "Dockur cache: ${DOCKUR_WINDOWS_DIR}"


    while IFS= read -r -d '' file; do

        info "Removing: ${file}"


        sudo rm -f "$file" \
            >/dev/null 2>&1 ||
            true

    done < <(
        find "$DOCKUR_WINDOWS_DIR" \
            -type f \
            \( -iname '*.iso' -o -iname '*.img' \) \
            -print0 \
            2>/dev/null
    )


    if [[ -d "${DOCKUR_WINDOWS_DIR}/cache" ]]; then

        info "Removing Dockur cache directory..."


        sudo rm -rf \
            "${DOCKUR_WINDOWS_DIR}/cache" \
            >/dev/null 2>&1 ||
            true
    fi


    ok "Dockur cache cleanup hoàn tất."
}


# ==============================================================
# DISK CHECK
# ==============================================================

check_disk_capacity() {

    section "DISK CHECK"


    HOST_FREE_GB="$(host_free_gb)"


    echo "Host free disk : ${HOST_FREE_GB} GB"
    echo "Required disk  : ${DISK_SIZE}"


    if [[ "$HOST_FREE_GB" =~ ^[0-9]+$ ]] &&
       (( HOST_FREE_GB < MIN_HOST_FREE_DISK_GB )); then

        error "Host không đủ dung lượng cho Windows ${DISK_SIZE}."


        echo
        echo "Host free disk : ${HOST_FREE_GB} GB"
        echo "Windows disk   : ${DISK_SIZE}"
        echo
        echo "Không tạo container."
        echo "Không chạy restart loop."
        echo
        echo "Hãy giải phóng hoặc tăng dung lượng Codespace."
        echo


        return 1
    fi


    ok "Disk capacity check passed."
}


# ==============================================================
# CLEAR WINDOWS
# ==============================================================

clear_windows_all() {

    section "CLEAR WINDOWS"


    if [[ "$CLEAR_WINDOWS" == "OFF" ]]; then

        info "CLEAR_WINDOWS=OFF"
        info "Giữ nguyên Windows."
        info "Giữ nguyên storage."
        info "Giữ nguyên Dockur cache."
        info "Không dọn Docker."

        return 0
    fi


    if [[ "$FORCE_REINSTALL" == "OFF" ]]; then

        info "FORCE_REINSTALL=OFF"
        info "Không xóa Windows."

        return 0
    fi


    warn "CLEAR_WINDOWS=ON"
    warn "FORCE_REINSTALL=ON"
    warn "ĐANG DỌN SẠCH WINDOWS + DOCKER + CACHE."

    echo


    info "Stopping windows..."


    docker stop windows \
        2>/dev/null ||
        true


    info "Removing windows..."


    docker rm -f windows \
        2>/dev/null ||
        true


    info "Removing ${STORAGE_VOLUME}..."


    docker volume rm \
        -f \
        "$STORAGE_VOLUME" \
        2>/dev/null ||
        true


    info "Removing stopped containers..."


    docker container prune \
        -f \
        >/dev/null 2>&1 ||
        true


    info "Removing unused volumes..."


    docker volume prune \
        -af \
        >/dev/null 2>&1 ||
        true


    info "Removing unused networks..."


    docker network prune \
        -f \
        >/dev/null 2>&1 ||
        true


    info "Running docker system prune..."


    docker system prune \
        -af \
        --volumes \
        -f \
        >/dev/null 2>&1 ||
        true


    info "Removing build cache..."


    docker builder prune \
        -af \
        -f \
        >/dev/null 2>&1 ||
        true


    if [[ "$REMOVE_WINDOWS_IMAGE" == "ON" ]]; then

        if docker image inspect "$IMAGE" \
            >/dev/null 2>&1; then

            info "Removing ${IMAGE}..."


            docker rmi \
                -f \
                "$IMAGE" \
                >/dev/null 2>&1 ||
                true
        fi

    else

        info "Giữ Docker image."
    fi


    docker system prune \
        -af \
        --volumes \
        -f \
        >/dev/null 2>&1 ||
        true


    docker builder prune \
        -af \
        -f \
        >/dev/null 2>&1 ||
        true


    clear_dockur_cache


    cleanup_host_space


    echo

    section "DISK AFTER CLEAR"

    df -h /


    echo

    section "DOCKER AFTER CLEAR"

    docker system df \
        2>/dev/null ||
        true


    echo

    ok "CLEAR WINDOWS hoàn tất."
}


# ==============================================================
# IMAGE
# ==============================================================

prepare_image() {

    section "DOCKER IMAGE"


    if docker image inspect "$IMAGE" \
        >/dev/null 2>&1; then

        ok "Docker image đã có."

        return 0
    fi


    info "Pulling ${IMAGE}..."


    docker pull "$IMAGE" ||
        die "Docker image pull thất bại."


    ok "Docker image đã sẵn sàng."
}


# ==============================================================
# STORAGE
# ==============================================================

ensure_storage() {

    if volume_exists; then

        ok "Storage ${STORAGE_VOLUME} đã tồn tại."

        return 0
    fi


    info "Storage chưa tồn tại."


    docker volume create \
        "$STORAGE_VOLUME" \
        >/dev/null ||
        die "Không tạo được storage."


    ok "Storage mới đã tạo."
}


# ==============================================================
# CREATE WINDOWS
# ==============================================================

create_windows() {

    section "CREATE WINDOWS SERVER 2022"


    calculate_ram


    echo "Image       : ${IMAGE}"
    echo "Version     : ${WINDOWS_VERSION}"
    echo "CPU         : ${CPU_CORES}"
    echo "RAM MODE    : ${RAM_MODE}"
    echo "RAM         : ${EFFECTIVE_RAM_SIZE}"
    echo "RAM MAX     : ${RAM_MAX_GB}G"
    echo "DISK        : ${DISK_SIZE}"
    echo "DISK FORMAT : ${DISK_FMT}"
    echo "STORAGE     : ${STORAGE_VOLUME}"
    echo "KVM         : ${KVM}"
    echo "HV          : ${HV}"
    echo "VNC         : ${CONSOLE_PORT}"
    echo "RDP         : ${RDP_PORT}"
    echo "CLIP        : ${NOVNC_CLIP_TO_WINDOW}"
    echo "SCALING     : ${NOVNC_SCALING_MODE}"
    echo "RESTART     : ${AUTO_RESTART}"


    echo


    ensure_storage


    local KVM_YN
    local HV_YN
    local AUTOLOGIN_YN
    local RAM_CHECK_YN
    local WEB_YN
    local restart_policy


    KVM_YN="$(flag_to_yn "$KVM")"
    HV_YN="$(flag_to_yn "$HV")"
    AUTOLOGIN_YN="$(flag_to_yn "$AUTOLOGIN")"
    RAM_CHECK_YN="$(flag_to_yn "$RAM_CHECK")"
    WEB_YN="$(flag_to_yn "$WEB")"


    if [[ "$AUTO_RESTART" == "ON" ]]; then
        restart_policy="always"
    else
        restart_policy="no"
    fi


    docker run -d \
        --name "$NAME" \
        --restart="$restart_policy" \
        --stop-timeout 120 \
        \
        -e "VERSION=${WINDOWS_VERSION}" \
        \
        -e "CPU_CORES=${CPU_CORES}" \
        -e "CPU_MODEL=${CPU_MODEL}" \
        \
        -e "RAM_SIZE=${EFFECTIVE_RAM_SIZE}" \
        -e "RAM_CHECK=${RAM_CHECK_YN}" \
        \
        -e "DISK_SIZE=${DISK_SIZE}" \
        -e "DISK_FMT=${DISK_FMT}" \
        \
        -e "KVM=${KVM_YN}" \
        -e "HV=${HV_YN}" \
        \
        -e "USERNAME=${USERNAME}" \
        -e "PASSWORD=${PASSWORD}" \
        -e "AUTOLOGIN=${AUTOLOGIN_YN}" \
        \
        -e "DISPLAY=${DISPLAY}" \
        -e "WEB=${WEB_YN}" \
        -e "WEB_PORT=${WEB_PORT}" \
        \
        -e "WIDTH=${WIDTH}" \
        -e "HEIGHT=${HEIGHT}" \
        \
        -p "${CONSOLE_PORT}:8006/tcp" \
        -p "${RDP_PORT}:3389/tcp" \
        -p "${RDP_PORT}:3389/udp" \
        \
        --device=/dev/kvm \
        --device=/dev/net/tun \
        --cap-add=NET_ADMIN \
        \
        -v "${STORAGE_VOLUME}:/storage" \
        \
        "$IMAGE" || \
        die "Không tạo được Windows container."


    ok "Windows container đã tạo."

    echo

    info "VNC: http://127.0.0.1:${CONSOLE_PORT}"
    info "RDP: ${TAILSCALE_IP}:${RDP_PORT}"
    info "Resolution: ${WIDTH}x${HEIGHT}"
}


# ==============================================================
# EXISTING WINDOWS
# ==============================================================

use_existing_windows() {

    section "EXISTING WINDOWS"


    local status

    status="$(container_status)"


    echo "Status        : ${status}"
    echo "Restart policy: $(container_restart_policy)"
    echo "Restart count : $(container_restart_count)"

    echo


    case "$status" in

        running)

            ok "Windows container đang chạy."

            return 0
            ;;


        exited|dead|created)

            info "Container không chạy."
            info "Đang start lại..."


            docker start "$NAME" \
                >/dev/null ||
                die "Không thể start Windows container."


            ok "Windows container đã start lại."

            return 0
            ;;


        restarting)

            warn "Container đang restarting."

            return 0
            ;;


        *)

            warn "Container state: ${status}"

            return 0
            ;;
    esac
}


# ==============================================================
# WINDOWS WAIT
# ==============================================================

wait_windows() {

    section "WINDOWS INSTALL"


    calculate_ram


    info "Đang chờ Windows Server 2022..."
    info "RAM: ${EFFECTIVE_RAM_SIZE}"
    info "RAM MAX: ${RAM_MAX_GB}G"
    info "RESTART: ${AUTO_RESTART}"
    info "Mất VNC không làm reinstall."
    info "Mất VNC không làm CLEAR."
    info "Windows reboot không làm reinstall."


    echo


    local last_status=""
    local current_status=""


    for i in $(seq 1 "$WINDOWS_BOOT_LOOPS"); do


        if ! container_exists; then

            error "Container Windows đã biến mất."


            section "WINDOWS LOG"

            last_logs


            return 1
        fi


        current_status="$(container_status)"


        if [[ "$current_status" != "$last_status" ]]; then

            echo

            info "Container status: ${current_status}"

            last_status="$current_status"
        fi


        if windows_disk_error; then

            error "Dockur báo thiếu dung lượng."


            echo
            echo "Host free disk : $(host_free_gb) GB"
            echo "Windows disk   : ${DISK_SIZE}"
            echo


            section "WINDOWS LOG"

            last_logs


            return 1
        fi


        if [[ "$current_status" == "exited" ||
              "$current_status" == "dead" ]]; then

            error "Windows container đã thoát."


            echo
            echo "Exit code     : $(container_exit_code)"
            echo "Restart count : $(container_restart_count)"
            echo


            section "WINDOWS LOG"

            last_logs


            return 1
        fi


        if [[ "$current_status" == "restarting" ]]; then

            warn "Container đang restarting."


            printf '\rWindows setup: %3d/%s' \
                "$i" \
                "$WINDOWS_BOOT_LOOPS"


            sleep "$WINDOWS_BOOT_INTERVAL"


            continue
        fi


        if container_running &&
           windows_ready; then

            echo

            ok "Windows Server 2022: READY"

            return 0
        fi


        printf '\rWindows setup: %3d/%s' \
            "$i" \
            "$WINDOWS_BOOT_LOOPS"


        sleep "$WINDOWS_BOOT_INTERVAL"
    done


    echo

    error "Windows Setup timeout."


    section "WINDOWS LOG"

    last_logs


    return 1
}


# ==============================================================
# FIND NOVNC
# ==============================================================

find_novnc_html() {

    docker exec "$NAME" sh -c '
        for p in \
            /usr/share/novnc/vnc.html \
            /usr/share/novnc/vnc_lite.html \
            /novnc/vnc.html \
            /app/vnc.html
        do
            if [ -f "$p" ]; then
                echo "$p"
                exit 0
            fi
        done

        find / \
            -type f \
            -name "vnc.html" \
            2>/dev/null |
            head -1
    ' 2>/dev/null || true
}


# ==============================================================
# NOVNC CONFIG
# ==============================================================

configure_novnc() {

    section "NOVNC CONFIG"


    if ! container_running; then

        warn "Container chưa chạy."

        return 0
    fi


    local vnc_html
    local novnc_dir


    vnc_html="$(find_novnc_html)"


    if [[ -z "$vnc_html" ]]; then

        warn "Không tìm thấy vnc.html."

        return 0
    fi


    novnc_dir="$(dirname "$vnc_html")"


    info "noVNC directory: ${novnc_dir}"


    # ==========================================================
    # INTERNAL VALUES
    #
    # User-facing config:
    #   ON / OFF
    #
    # noVNC:
    #   view_clip = boolean
    #   resize    = off / scale / remote
    # ==========================================================

    local clip_value="false"
    local resize_value="scale"


    if [[ "$NOVNC_CLIP_TO_WINDOW" == "ON" ]]; then

        clip_value="true"
    fi


    if [[ "$NOVNC_SCALING_MODE" == "ON" ]]; then

        # None/off is required so clipViewport handles overflow.
        resize_value="off"
    fi


    # ==========================================================
    # MANDATORY.JSON
    # ==========================================================
    #
    # mandatory settings cannot be changed by the user.
    # ==============================================================

    docker exec "$NAME" sh -c "
        cat > '${novnc_dir}/mandatory.json' <<'EOF'
{
    \"view_clip\": ${clip_value},
    \"resize\": \"${resize_value}\"
}
EOF
    " >/dev/null 2>&1 || {

        warn "Không tạo được mandatory.json."

        return 0
    }


    ok "Clip to window: ${NOVNC_CLIP_TO_WINDOW}"
    ok "Scaling mode: ${NOVNC_SCALING_MODE}"


    # ==========================================================
    # HIDE SETTINGS
    # ==========================================================

    if [[ "$NOVNC_HIDE_CLIP_SETTING" == "ON" ||
          "$NOVNC_HIDE_SCALING_SETTING" == "ON" ]]; then


        docker exec "$NAME" sh -c "
            python3 - '${vnc_html}' \
            '${NOVNC_HIDE_CLIP_SETTING}' \
            '${NOVNC_HIDE_SCALING_SETTING}' <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
hide_clip = sys.argv[2] == 'ON'
hide_scale = sys.argv[3] == 'ON'

try:
    text = path.read_text(encoding='utf-8')
except Exception:
    raise SystemExit(0)

marker_start = '/* WINDOWS-NOVNC-HIDDEN-SETTINGS-START */'
marker_end = '/* WINDOWS-NOVNC-HIDDEN-SETTINGS-END */'

start = text.find(marker_start)
end = text.find(marker_end)

if start != -1 and end != -1 and end > start:
    end += len(marker_end)
    text = text[:start] + text[end:]

js = f'''
<script>
{marker_start}

(function() {{
    function hideSettings() {{

        const clip = document.getElementById(
            'noVNC_setting_view_clip'
        );

        const resize = document.getElementById(
            'noVNC_setting_resize'
        );

        if ({str(hide_clip).lower()} && clip) {{
            const li = clip.closest('li');
            if (li) {{
                li.style.display = 'none';
            }}
        }}

        if ({str(hide_scale).lower()} && resize) {{
            const li = resize.closest('li');
            if (li) {{
                li.style.display = 'none';
            }}
        }}
    }}

    hideSettings();

    if (document.readyState === 'loading') {{
        document.addEventListener(
            'DOMContentLoaded',
            hideSettings
        );
    }}

    setTimeout(hideSettings, 100);
    setTimeout(hideSettings, 500);
    setTimeout(hideSettings, 1000);
}})();

{marker_end}
</script>
'''

needle = '</body>'

if needle in text:
    text = text.replace(
        needle,
        js + '\\n' + needle,
        1
    )
else:
    text += '\\n' + js + '\\n'

path.write_text(text, encoding='utf-8')
PY
        " >/dev/null 2>&1 || true


        if [[ "$NOVNC_HIDE_CLIP_SETTING" == "ON" ]]; then

            ok "Clip to window setting: HIDDEN"
        fi


        if [[ "$NOVNC_HIDE_SCALING_SETTING" == "ON" ]]; then

            ok "Scaling mode setting: HIDDEN"
        fi
    fi


    ok "noVNC configuration complete."
}


# ==============================================================
# VNC WAIT
# ==============================================================

wait_vnc() {

    section "WEB VNC"


    info "Backend: ${DISPLAY}"
    info "Web UI: ${WEB}"
    info "Port: ${WEB_PORT}"
    info "Clip to window: ${NOVNC_CLIP_TO_WINDOW}"
    info "Scaling mode: ${NOVNC_SCALING_MODE}"


    for i in $(seq 1 "$VNC_WAIT_LOOPS"); do


        if ! container_running; then

            warn "Container không chạy."

            return 1
        fi


        if check_port "$CONSOLE_PORT"; then

            echo

            ok "VNC ${CONSOLE_PORT}: OPEN"
            ok "VNC Local: http://127.0.0.1:${CONSOLE_PORT}"


            return 0
        fi


        printf '\rVNC waiting: %3d/%s' \
            "$i" \
            "$VNC_WAIT_LOOPS"


        sleep "$VNC_WAIT_INTERVAL"

    done


    echo

    warn "VNC port ${CONSOLE_PORT} chưa mở."


    return 1
}


# ==============================================================
# RDP WAIT
# ==============================================================

wait_rdp() {

    section "RDP"


    info "RDP address: ${TAILSCALE_IP}:${RDP_PORT}"


    for i in $(seq 1 "$RDP_WAIT_LOOPS"); do


        if ! container_running; then

            warn "Container không chạy."

            return 1
        fi


        if check_port "$RDP_PORT"; then

            echo

            ok "RDP ${RDP_PORT}: OPEN"
            ok "RDP address: ${TAILSCALE_IP}:${RDP_PORT}"


            return 0
        fi


        printf '\rRDP waiting: %3d/%s' \
            "$i" \
            "$RDP_WAIT_LOOPS"


        sleep "$RDP_WAIT_INTERVAL"

    done


    echo

    warn "RDP ${RDP_PORT} chưa mở."


    echo
    echo "Kiểm tra:"
    echo "docker port ${NAME}"
    echo "ss -lntp | grep ':${RDP_PORT}'"


    return 1
}


# ==============================================================
# CODESPACES PORT
# ==============================================================

repair_port() {

    CODESPACE_VNC_URL=""


    [[ -n "${CODESPACE_NAME:-}" ]] ||
        return 0


    command -v gh >/dev/null 2>&1 ||
        return 0


    section "CODESPACES PORT"


    gh codespace ports visibility \
        "${CONSOLE_PORT}:public" \
        -c "$CODESPACE_NAME" \
        >/dev/null 2>&1 ||
        true


    sleep 2


    local json
    local browse
    local visibility


    json="$(
        gh codespace ports \
            -c "$CODESPACE_NAME" \
            --json sourcePort,browseUrl,visibility \
            2>/dev/null ||
            true
    )"


    if command -v jq >/dev/null 2>&1; then


        browse="$(
            printf '%s' "$json" |
            jq -r \
                --arg p "$CONSOLE_PORT" \
                '.[] |
                 select(
                    (.sourcePort|tostring)==$p
                 ) |
                 .browseUrl' |
            head -1
        )"


        visibility="$(
            printf '%s' "$json" |
            jq -r \
                --arg p "$CONSOLE_PORT" \
                '.[] |
                 select(
                    (.sourcePort|tostring)==$p
                 ) |
                 .visibility' |
            head -1
        )"


        if [[ -n "$browse" &&
              "$browse" != "null" ]]; then

            CODESPACE_VNC_URL="$browse"
        fi


        if [[ "$visibility" == "public" ]]; then

            ok "Port ${CONSOLE_PORT}: public"
        fi
    fi
}


# ==============================================================
# FINAL INFO
# ==============================================================

show_connection_info() {

    local tail_ip
    local guest_ip
    local status
    local policy
    local restart_count


    tail_ip="$(
        sudo tailscale ip -4 \
            2>/dev/null |
        head -1 ||
        true
    )"


    guest_ip="$(
        docker logs "$NAME" \
            2>&1 |
        grep -oE \
            'Guest: [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' |
        tail -1 |
        awk '{print $2}' ||
        true
    )"


    status="$(container_status)"
    policy="$(container_restart_policy)"
    restart_count="$(container_restart_count)"


    section "CONNECTION INFO"


    echo "Container    : ${status}"
    echo "Restart      : ${policy}"
    echo "RestartCount : ${restart_count}"
    echo "Guest IP     : ${guest_ip:-N/A}"
    echo "Storage      : ${STORAGE_VOLUME}"
    echo "Storage used : $(volume_size)"


    echo


    echo "WINDOWS:"
    echo "  CPU        : max"
    echo "  RAM MODE   : ${RAM_MODE}"
    echo "  RAM        : ${EFFECTIVE_RAM_SIZE}"
    echo "  RAM MAX    : ${RAM_MAX_GB}G"
    echo "  DISK       : ${DISK_SIZE}"
    echo "  FORMAT     : ${DISK_FMT}"
    echo "  RESOLUTION : ${WIDTH}x${HEIGHT}"


    echo


    echo "VNC:"
    echo "  Local      : http://127.0.0.1:${CONSOLE_PORT}"
    echo "  Clip       : ${NOVNC_CLIP_TO_WINDOW}"
    echo "  Scaling    : ${NOVNC_SCALING_MODE}"
    echo "  Hide Clip  : ${NOVNC_HIDE_CLIP_SETTING}"
    echo "  Hide Scale : ${NOVNC_HIDE_SCALING_SETTING}"


    if [[ -n "${CODESPACE_VNC_URL:-}" ]]; then

        echo "  Codespaces : ${CODESPACE_VNC_URL}"

    else

        echo "  Codespaces : Mở tab PORTS -> port ${CONSOLE_PORT}"
    fi


    echo


    echo "TAILSCALE:"
    echo "  IP         : ${tail_ip:-N/A}"


    echo


    echo "RDP:"
    echo "  Address    : ${tail_ip:-N/A}:${RDP_PORT}"
    echo "  Username   : ${USERNAME}"
    echo "  Password   : ${PASSWORD}"


    echo


    if check_port "$RDP_PORT"; then

        echo "  Status     : OPEN"

    else

        echo "  Status     : CLOSED"
    fi
}


# ==============================================================
# MAIN
# ==============================================================

clear 2>/dev/null || true


# ==============================================================
# 1. VALIDATE
# ==============================================================

validate_config


# ==============================================================
# 2. STATE
# ==============================================================

show_container_state


# ==============================================================
# 3. TAILSCALE
# ==============================================================

prepare_tailscale


# ==============================================================
# 4. HOST CHECK
# ==============================================================

check_prereqs


# ==============================================================
# 5. CLEAR
# ==============================================================

if [[ "$CLEAR_WINDOWS" == "ON" ]]; then

    if [[ "$FORCE_REINSTALL" == "ON" ]]; then

        clear_windows_all

    else

        section "CLEAR WINDOWS"

        info "CLEAR_WINDOWS=ON"
        info "FORCE_REINSTALL=OFF"
        info "Giữ nguyên Windows."
    fi

else

    section "CLEAR WINDOWS"

    info "CLEAR_WINDOWS=OFF"
    info "Giữ nguyên container."
    info "Giữ nguyên storage."
    info "Giữ nguyên Dockur cache."
    info "Không dọn Docker."
fi


# ==============================================================
# 6. DISK CHECK
# ==============================================================

if ! check_disk_capacity; then

    echo

    error "Dừng trước khi tạo Windows vì host không đủ disk."

    exit 1
fi


# ==============================================================
# 7. IMAGE
# ==============================================================

prepare_image


# ==============================================================
# 8. CLEAR OFF
# ==============================================================

if [[ "$CLEAR_WINDOWS" == "OFF" ]]; then

    if container_exists; then

        use_existing_windows >/dev/null || true

    else

        section "NO WINDOWS CONTAINER"


        if volume_exists; then

            ok "Storage ${STORAGE_VOLUME} vẫn tồn tại."
            info "Dữ liệu Windows được giữ nguyên."

        else

            info "Storage chưa tồn tại."
            info "Sẽ tạo storage mới."
        fi
    fi
fi


# ==============================================================
# 9. CREATE
# ==============================================================

if ! container_exists; then

    section "NEW WINDOWS CONTAINER"

    create_windows
fi


# ==============================================================
# 10. WINDOWS SERVER 2022
# ==============================================================

section "WINDOWS SERVER 2022"


calculate_ram


echo "Windows : ${WINDOWS_VERSION}"
echo "CPU     : max"
echo "RAM     : ${RAM_MODE} (${EFFECTIVE_RAM_SIZE}, max ${RAM_MAX_GB}G)"
echo "DISK    : ${DISK_SIZE}"
echo "FORMAT  : ${DISK_FMT}"
echo "STORAGE : ${STORAGE_VOLUME}"
echo "VNC     : ${CONSOLE_PORT}"
echo "RDP     : ${RDP_PORT}"
echo "CLIP    : ${NOVNC_CLIP_TO_WINDOW}"
echo "SCALING : ${NOVNC_SCALING_MODE}"
echo "CLEAR   : ${CLEAR_WINDOWS}"
echo "FORCE   : ${FORCE_REINSTALL}"
echo "RESTART : ${AUTO_RESTART}"


echo


# ==============================================================
# 11. WINDOWS READY
# ==============================================================

if ! wait_windows; then

    section "WINDOWS INSTALL FAILED"

    error "Windows Server 2022 không khởi động thành công."

    echo
    echo "Container KHÔNG bị xóa."
    echo "Storage KHÔNG bị xóa."
    echo "Không reinstall tự động."
    echo

    exit 1
fi


# ==============================================================
# 12. NOVNC
# ==============================================================

configure_novnc


# ==============================================================
# 13. CODESPACES
# ==============================================================

repair_port


# ==============================================================
# 14. VNC
# ==============================================================

wait_vnc || true


# ==============================================================
# 15. RDP
# ==============================================================

wait_rdp || true


# ==============================================================
# 16. FINAL
# ==============================================================

show_connection_info


echo

ok "Windows Server 2022 hoàn tất."