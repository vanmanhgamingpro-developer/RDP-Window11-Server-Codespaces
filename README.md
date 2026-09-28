# Windows Server 2022 Docker + KVM + Tailscale + Web VNC + RDP

Script Bash này tự động triển khai **Windows Server 2022** trong Docker bằng image `dockurr/windows:latest`, sử dụng **KVM/HV** để tăng tốc ảo hóa, **Tailscale** để truy cập từ xa qua mạng riêng, **noVNC/Web VNC** để điều khiển Windows bằng trình duyệt và **RDP** để kết nối Remote Desktop.

> **Lưu ý quan trọng:** Script gốc có chứa thông tin đăng nhập Windows và Tailscale Auth Key. Không đưa các secret thật lên GitHub. Hãy thay chúng bằng giá trị mới trước khi public repository. Auth Key đã từng bị lộ cũng không nên tiếp tục sử dụng.

---

## 1. Tính năng

Script thực hiện các công việc chính sau:

- Tạo Windows Server 2022 bằng Docker.
- Sử dụng `dockurr/windows:latest`.
- Bật KVM/HV cho máy ảo.
- Tự động cấp CPU tối đa (`CPU_CORES=max`).
- CPU model dùng `host`.
- Tự động tính RAM hoặc dùng RAM cố định.
- RAM AUTO có giới hạn:
  - Tối thiểu: `4G`
  - Tối đa: `10G`
  - Chừa lại: `1G` cho host
- Tạo ổ Windows `20G` định dạng `qcow2`.
- Lưu dữ liệu Windows trong Docker named volume.
- Tự động cài và đăng nhập Tailscale bằng Auth Key.
- Có Web VNC/noVNC trên port `8006`.
- Có RDP trên port `3389`.
- Có thể bật auto restart cho container.
- Có chức năng xóa Windows + storage + Docker cache + Dockur cache trước khi cài lại.
- Có kiểm tra CPU, RAM và dung lượng ổ đĩa của host.
- Có kiểm tra trạng thái container, exit code và restart count.
- Tự động chờ Windows khởi động hoàn tất.
- Tự động kiểm tra VNC và RDP.
- Tự động chỉnh noVNC:
  - Clip to window
  - Scaling mode
  - Ẩn phần cài đặt Clip
  - Ẩn phần cài đặt Scaling
- Hỗ trợ GitHub Codespaces để tự động public port Web VNC và lấy `browseUrl` khi có `gh` + `jq`.

---

## 2. Kiến trúc

```text
Linux Host
│
├── Docker
│   └── Container: windows
│       └── dockurr/windows:latest
│           └── Windows Server 2022
│
├── /dev/kvm
│   └── KVM acceleration
│
├── /dev/net/tun
│   └── TUN device
│
├── Docker Volume
│   └── windows-storage
│       └── Windows data
│
└── Tailscale
    └── Tailscale IP
        └── RDP :3389
```

Luồng truy cập:

```text
Trình duyệt
   │
   └── Web VNC :8006
           │
           ▼
      Windows Server 2022

Remote Desktop Client
   │
   └── Tailscale IP :3389
           │
           ▼
      Windows Server 2022
```

---

## 3. Thông số mặc định

| Thành phần | Giá trị |
|---|---|
| Windows | Server 2022 |
| Docker image | `dockurr/windows:latest` |
| Container | `windows` |
| CPU | `max` |
| CPU model | `host` |
| RAM mode | `AUTO` |
| RAM tối thiểu | `4G` |
| RAM tối đa | `10G` |
| RAM reserve host | `1G` |
| Disk | `20G` |
| Disk format | `qcow2` |
| Storage | `windows-storage` |
| Web VNC | `8006` |
| RDP TCP | `3389` |
| RDP UDP | `3389` |
| Resolution | `1280x720` |
| Auto restart | `ON` |
| KVM | `ON` |
| HV | `ON` |
| AUTOLOGIN | `ON` |
| RAM check | `ON` |
| Web | `ON` |
| noVNC Clip | `ON` |
| noVNC Scaling | `ON` |
| Hide Clip setting | `ON` |
| Hide Scaling setting | `ON` |

---

## 4. Yêu cầu host

Script kiểm tra các điều kiện tối thiểu trước khi tạo Windows.

### CPU

Tối thiểu:

```text
2 CPU cores
```

Script lấy số core bằng:

```bash
nproc
```

### RAM

Script yêu cầu host có tối thiểu:

```text
15 GB RAM
```

Mục đích là để Windows VM/container có đủ RAM trong khi vẫn giữ tài nguyên cho host.

### Dung lượng ổ đĩa

Script kiểm tra dung lượng trống của filesystem chứa `$HOME`.

Ngưỡng tối thiểu:

```text
20 GB free
```

Nếu không đủ, script sẽ dừng trước khi tạo Windows container.

### KVM

Bắt buộc có:

```text
/dev/kvm
```

Kiểm tra:

```bash
ls -l /dev/kvm
```

Nếu không có, script sẽ dừng.

### TUN

Script yêu cầu:

```text
/dev/net/tun
```

Nếu chưa có, script sẽ thử:

```bash
sudo mkdir -p /dev/net
sudo modprobe tun
```

Sau đó kiểm tra lại.

### Công cụ chính

Host cần có các thành phần phục vụ script:

```text
bash
docker
curl
sudo
nproc
free
df
```

Một số thao tác dọn cache còn gọi:

```text
python3
pip
npm
```

Nếu các lệnh cache không tồn tại, script dùng `|| true` để không làm toàn bộ tiến trình dừng lại.

GitHub Codespaces còn sử dụng tùy chọn:

```text
gh
jq
```

nếu có sẵn.

---

## 5. Các biến cấu hình

Phần cấu hình nằm ở đầu script.

### Tên container

```bash
NAME="windows"
```

Container Docker được tạo với tên:

```text
windows
```

---

### Docker image

```bash
IMAGE="dockurr/windows:latest"
```

Script sẽ kiểm tra image. Nếu chưa có thì chạy:

```bash
docker pull dockurr/windows:latest
```

---

### Phiên bản Windows

```bash
WINDOWS_VERSION="2022"
```

Docker container được cấu hình để sử dụng Windows Server 2022.

---

## 6. Tài khoản Windows

Script có hai biến:

```bash
USERNAME="..."
PASSWORD="..."
```

Ví dụ trong repository công khai nên dùng:

```bash
USERNAME="your-user"
PASSWORD="CHANGE_ME"
```

**Không commit mật khẩu thật lên GitHub.**

Tốt hơn nữa là lấy secret từ environment variable:

```bash
USERNAME="${WINDOWS_USERNAME:?Windows username is required}"
PASSWORD="${WINDOWS_PASSWORD:?Windows password is required}"
```

---

## 7. Tailscale

Script sử dụng:

```bash
TS_AUTH_KEY="..."
```

Sau đó tự động:

1. Kiểm tra Tailscale.
2. Nếu chưa cài thì cài.
3. Enable `tailscaled`.
4. Start `tailscaled`.
5. Logout session hiện tại.
6. Login lại bằng Auth Key.
7. Lấy IPv4 của Tailscale.
8. Tắt việc nhận DNS của Tailscale.

Các thao tác chính:

```bash
sudo tailscale logout
sudo tailscale up \
  --auth-key="$TS_AUTH_KEY" \
  --hostname="windows-${CODESPACE_NAME:-codespace}" \
  --timeout=60s

sudo tailscale ip -4
sudo tailscale set --accept-dns=false
```

### Bảo mật Tailscale

Không commit Auth Key thật:

```bash
TS_AUTH_KEY="tskey-..."
```

Trong repository public nên dùng:

```bash
TS_AUTH_KEY="${TS_AUTH_KEY:?Tailscale Auth Key is required}"
```

Sau đó cấp key từ environment.

> Nếu Auth Key từng được đăng công khai, nên thu hồi/xóa key cũ và tạo key mới trong Tailscale.

---

# 8. Chế độ CLEAR_WINDOWS và FORCE_REINSTALL

Hai biến quan trọng:

```bash
CLEAR_WINDOWS="ON"
FORCE_REINSTALL="ON"
```

## CLEAR_WINDOWS

### ON

Script sẽ thực hiện quá trình dọn Windows và Docker:

- stop container
- remove container
- remove named volume
- prune container
- prune volume
- prune network
- Docker system prune
- Docker builder prune
- xóa Windows image nếu được bật
- xóa Dockur cache
- dọn APT cache
- dọn temporary files
- dọn pip cache
- dọn npm cache
- dọn user cache

### OFF

Script giữ nguyên:

- Windows container
- Windows storage
- Dockur cache
- Docker data liên quan

Ví dụ:

```bash
CLEAR_WINDOWS="OFF"
```

---

## FORCE_REINSTALL

### ON

Khi kết hợp:

```bash
CLEAR_WINDOWS="ON"
FORCE_REINSTALL="ON"
```

script sẽ xóa dữ liệu Windows và tạo lại từ đầu.

### OFF

Script không thực hiện việc xóa Windows.

Ví dụ:

```bash
CLEAR_WINDOWS="ON"
FORCE_REINSTALL="OFF"
```

Trong trường hợp này script sẽ báo rằng không reinstall.

---

# 9. Cảnh báo cực kỳ quan trọng về xóa dữ liệu

Đoạn:

```bash
docker volume rm -f "$STORAGE_VOLUME"
```

sẽ xóa Docker volume:

```text
windows-storage
```

Volume này chứa dữ liệu Windows.

Ngoài ra script còn chạy:

```bash
docker volume prune -af
docker system prune -af --volumes -f
```

Điều này có thể xóa **các Docker resource không còn được dùng khác trên host**, không chỉ Windows.

Vì vậy:

```bash
CLEAR_WINDOWS="ON"
FORCE_REINSTALL="ON"
```

chỉ nên sử dụng khi bạn thực sự muốn cài Windows mới và hiểu rằng dữ liệu Docker có thể bị xóa.

---

# 10. Xóa Windows image

Biến:

```bash
REMOVE_WINDOWS_IMAGE="ON"
```

Nếu bật, script có thể xóa:

```text
dockurr/windows:latest
```

bằng:

```bash
docker rmi -f "$IMAGE"
```

Sau đó image sẽ được pull lại khi cài mới.

Nếu muốn giữ image:

```bash
REMOVE_WINDOWS_IMAGE="OFF"
```

---

# 11. Auto Restart

Biến:

```bash
AUTO_RESTART="ON"
```

Khi ON:

```bash
--restart=always
```

Khi OFF:

```bash
--restart=no
```

Mục đích của chế độ ON là Docker tự khởi động lại Windows container nếu container bị dừng.

---

# 12. CPU

Cấu hình:

```bash
CPU_CORES="max"
CPU_MODEL="host"
```

Docker container nhận:

```text
CPU_CORES=max
```

và:

```text
CPU_MODEL=host
```

Script bắt buộc:

```bash
CPU_CORES="max"
```

Nếu đổi sang giá trị khác, `validate_config()` sẽ dừng script.

---

# 13. RAM AUTO

Mặc định:

```bash
RAM_MODE="AUTO"
RAM_MAX_GB="10"
RAM_MIN_GB="4"
RAM_RESERVE_GB="1"
```

Cách tính:

```text
Available RAM
    -
RAM_RESERVE_GB
    =
Calculated RAM
```

Sau đó script giới hạn kết quả:

```text
Không thấp hơn 4G
Không cao hơn 10G
```

Ví dụ:

```text
Available = 8G
Reserve   = 1G

Calculated = 7G
```

Kết quả:

```text
RAM = 7G
```

Ví dụ host có:

```text
Available = 20G
```

thì:

```text
20 - 1 = 19G
```

nhưng vì giới hạn tối đa:

```text
RAM_MAX_GB=10
```

Windows sẽ nhận:

```text
10G
```

---

# 14. RAM FIXED

Có thể chuyển:

```bash
RAM_MODE="FIXED"
```

và đặt:

```bash
RAM_SIZE="12G"
```

Khi đó script dùng:

```text
RAM_SIZE=12G
```

thay vì tính AUTO.

Điều kiện:

```text
RAM_SIZE phải có dạng số + G
```

Ví dụ hợp lệ:

```bash
RAM_SIZE="8G"
RAM_SIZE="10G"
RAM_SIZE="12G"
```

Ví dụ không hợp lệ:

```bash
RAM_SIZE="8192"
RAM_SIZE="8GB"
```

---

# 15. Disk

Script cố định:

```bash
DISK_SIZE="20G"
DISK_FMT="qcow2"
```

Phần validation bắt buộc:

```text
DISK_SIZE = 20G
DISK_FMT = qcow2
```

Do đó nếu sửa sang kích thước khác, `validate_config()` sẽ báo lỗi.

---

# 16. Docker Storage

Windows sử dụng Docker named volume:

```bash
STORAGE_VOLUME="windows-storage"
```

Script kiểm tra:

```bash
docker volume inspect windows-storage
```

Nếu chưa có:

```bash
docker volume create windows-storage
```

Container mount volume vào:

```text
/storage
```

Tức là:

```text
Docker volume: windows-storage
            ↓
Container: /storage
```

---

# 17. Dockur cache

Script sử dụng thư mục:

```bash
DOCKUR_WINDOWS_DIR="/home/codespace/windows"
```

Phần cleanup tìm các file:

```text
*.iso
*.img
```

và xóa thư mục:

```text
/home/codespace/windows/cache
```

Nếu chạy ngoài GitHub Codespaces, cần kiểm tra xem thư mục này có đúng với môi trường thực tế hay không.

---

# 18. Windows Display

Độ phân giải mặc định:

```bash
WIDTH="1280"
HEIGHT="720"
```

Kết quả:

```text
1280x720
```

---

# 19. Web VNC / noVNC

Cấu hình:

```bash
DISPLAY="web"
WEB_PORT="8006"
CONSOLE_PORT="8006"
WEB="ON"
```

Container publish:

```bash
-p "${CONSOLE_PORT}:8006/tcp"
```

Vì vậy host dùng:

```text
8006
```

Địa chỉ local:

```text
http://127.0.0.1:8006
```

---

# 20. Cấu hình noVNC

Script muốn mặc định:

```bash
NOVNC_CLIP_TO_WINDOW="ON"
NOVNC_SCALING_MODE="ON"

NOVNC_HIDE_CLIP_SETTING="ON"
NOVNC_HIDE_SCALING_SETTING="ON"
```

Script chuyển các giá trị user-facing:

```text
ON / OFF
```

thành giá trị nội bộ của noVNC.

### Clip to window

Khi:

```bash
NOVNC_CLIP_TO_WINDOW="ON"
```

script ghi:

```json
{
  "view_clip": true
}
```

### Scaling

Khi:

```bash
NOVNC_SCALING_MODE="ON"
```

script đặt:

```json
{
  "resize": "off"
}
```

Theo logic trong script, cấu hình này được dùng cùng clip viewport để xử lý phần hiển thị vượt quá cửa sổ.

---

# 21. mandatory.json

Script tìm `vnc.html` trong các vị trí phổ biến:

```text
/usr/share/novnc/vnc.html
/usr/share/novnc/vnc_lite.html
/novnc/vnc.html
/app/vnc.html
```

Nếu không tìm thấy ở các vị trí trên, script thực hiện:

```bash
find / -type f -name "vnc.html"
```

Sau đó tạo:

```text
mandatory.json
```

Ví dụ:

```json
{
  "view_clip": true,
  "resize": "off"
}
```

Mục đích là giữ các cấu hình noVNC mong muốn.

---

# 22. Ẩn các tùy chọn noVNC

Script chèn JavaScript vào `vnc.html`.

Hai element được xử lý:

```text
noVNC_setting_view_clip
noVNC_setting_resize
```

Nếu bật:

```bash
NOVNC_HIDE_CLIP_SETTING="ON"
NOVNC_HIDE_SCALING_SETTING="ON"
```

script sẽ ẩn mục tương ứng khỏi giao diện.

Script sử dụng marker:

```text
/* WINDOWS-NOVNC-HIDDEN-SETTINGS-START */
/* WINDOWS-NOVNC-HIDDEN-SETTINGS-END */
```

để tránh chèn JavaScript lặp lại.

---

# 23. RDP

Cấu hình:

```bash
RDP_PORT="3389"
```

Container publish:

```bash
-p "${RDP_PORT}:3389/tcp"
-p "${RDP_PORT}:3389/udp"
```

Do đó RDP sử dụng:

```text
TCP 3389
UDP 3389
```

Địa chỉ script hiển thị theo dạng:

```text
TAILSCALE_IP:3389
```

Ví dụ:

```text
100.x.x.x:3389
```

---

# 24. Tailscale + RDP

Script lấy Tailscale IPv4 bằng:

```bash
sudo tailscale ip -4
```

Sau đó RDP address được hiển thị:

```text
TAILSCALE_IP:3389
```

Cách sử dụng:

```text
Remote Desktop Client
        ↓
Tailscale IP
        ↓
:3389
        ↓
Windows Server 2022
```

Điều này giúp RDP đi qua mạng Tailscale thay vì phải mở RDP trực tiếp ra Internet.

---

# 25. GitHub Codespaces

Script có phần:

```bash
repair_port()
```

Nếu biến:

```text
CODESPACE_NAME
```

tồn tại và có:

```text
gh
```

script sẽ cố gắng đặt port `8006` thành public:

```bash
gh codespace ports visibility \
  "8006:public" \
  -c "$CODESPACE_NAME"
```

Sau đó lấy:

```text
sourcePort
browseUrl
visibility
```

Nếu có `jq`, script sẽ tìm URL của port `8006`.

Nếu thành công, output sẽ có:

```text
Codespaces: <browse URL>
```

Nếu không lấy được URL, script hướng dẫn mở:

```text
PORTS → port 8006
```

---

# 26. Kiểm tra host

Hàm:

```bash
check_prereqs()
```

kiểm tra:

```text
Docker đã cài
Docker daemon đang chạy
/dev/kvm tồn tại
/dev/net/tun tồn tại
curl đã cài
sudo hoạt động
CPU
RAM
Disk
```

Script cũng chạy:

```bash
docker info
```

để xác nhận Docker daemon hoạt động.

---

# 27. Kiểm tra dung lượng

Script kiểm tra dung lượng trống:

```bash
df -BG "$HOME"
```

Sau đó so với:

```bash
MIN_HOST_FREE_DISK_GB=20
```

Nếu dưới mức này:

```text
Không tạo container
Không chạy restart loop
```

và script kết thúc với lỗi.

---

# 28. Host Cleanup

Hàm:

```bash
cleanup_host_space()
```

thực hiện:

```bash
sudo apt-get clean
sudo apt-get autoclean
```

Dọn:

```text
/tmp
/var/tmp
```

Dọn pip cache:

```bash
python3 -m pip cache purge
```

Dọn npm cache:

```bash
npm cache clean --force
```

Dọn:

```text
~/.cache/pip
~/.cache/npm
~/.cache/yarn
~/.cache/pnpm
```

Sau đó hiển thị:

```bash
df -h /
```

---

# 29. Container State

Script có các hàm:

```bash
container_exists()
container_running()
container_status()
container_exit_code()
container_restart_count()
container_restart_policy()
```

Nhờ đó script có thể phát hiện:

```text
running
exited
dead
created
restarting
```

và quyết định có start lại container hay không.

---

# 30. Dùng Windows hiện có

Khi:

```bash
CLEAR_WINDOWS="OFF"
```

và container đã tồn tại, script sẽ gọi:

```bash
use_existing_windows
```

Nếu container:

```text
running
```

thì giữ nguyên.

Nếu:

```text
exited
dead
created
```

script sẽ chạy:

```bash
docker start windows
```

Nếu:

```text
restarting
```

script chỉ cảnh báo và tiếp tục.

---

# 31. Quá trình tạo container

Container được tạo bằng `docker run -d`.

Các biến chính được truyền vào container:

```text
VERSION
CPU_CORES
CPU_MODEL
RAM_SIZE
RAM_CHECK
DISK_SIZE
DISK_FMT
KVM
HV
USERNAME
PASSWORD
AUTOLOGIN
DISPLAY
WEB
WEB_PORT
WIDTH
HEIGHT
```

Thiết bị được cấp:

```text
/dev/kvm
/dev/net/tun
```

và capability:

```text
NET_ADMIN
```

Storage:

```text
windows-storage:/storage
```

---

# 32. Docker command tương đương

Logic chính của script tương đương với dạng:

```bash
docker run -d \
  --name windows \
  --restart=always \
  --stop-timeout 120 \
  -e "VERSION=2022" \
  -e "CPU_CORES=max" \
  -e "CPU_MODEL=host" \
  -e "RAM_SIZE=4G" \
  -e "RAM_CHECK=Y" \
  -e "DISK_SIZE=20G" \
  -e "DISK_FMT=qcow2" \
  -e "KVM=Y" \
  -e "HV=Y" \
  -e "USERNAME=YOUR_USERNAME" \
  -e "PASSWORD=YOUR_PASSWORD" \
  -e "AUTOLOGIN=Y" \
  -e "DISPLAY=web" \
  -e "WEB=Y" \
  -e "WEB_PORT=8006" \
  -e "WIDTH=1280" \
  -e "HEIGHT=720" \
  -p "8006:8006/tcp" \
  -p "3389:3389/tcp" \
  -p "3389:3389/udp" \
  --device=/dev/kvm \
  --device=/dev/net/tun \
  --cap-add=NET_ADMIN \
  -v "windows-storage:/storage" \
  dockurr/windows:latest
```

> Phần trên chỉ là minh họa. Khi chạy script thật, RAM sẽ được tính theo `RAM_MODE`.

---

# 33. Quy trình chạy tổng thể

Script chạy theo thứ tự:

```text
1. clear terminal
       ↓
2. validate_config
       ↓
3. show_container_state
       ↓
4. prepare_tailscale
       ↓
5. check_prereqs
       ↓
6. clear_windows_all (nếu cần)
       ↓
7. check_disk_capacity
       ↓
8. prepare_image
       ↓
9. xử lý Windows hiện tại
       ↓
10. create_windows (nếu chưa tồn tại)
       ↓
11. wait_windows
       ↓
12. configure_novnc
       ↓
13. repair_port
       ↓
14. wait_vnc
       ↓
15. wait_rdp
       ↓
16. show_connection_info
```

---

# 34. Kiểm tra Windows đã READY

Script theo dõi Docker logs và tìm:

```text
Windows started successfully
```

hoặc:

```text
Windows started succesfully
```

Nếu tìm thấy và container đang chạy:

```text
Windows Server 2022: READY
```

Nếu container `exited` hoặc `dead`, script hiển thị logs.

Nếu timeout:

```text
Windows Setup timeout.
```

và in:

```text
docker logs
```

---

# 35. Thời gian chờ mặc định

Windows:

```bash
WINDOWS_BOOT_LOOPS=360
WINDOWS_BOOT_INTERVAL=5
```

Tối đa khoảng:

```text
360 × 5 = 1800 giây
≈ 30 phút
```

VNC:

```bash
VNC_WAIT_LOOPS=60
VNC_WAIT_INTERVAL=2
```

Tối đa khoảng:

```text
60 × 2 = 120 giây
≈ 2 phút
```

RDP:

```bash
RDP_WAIT_LOOPS=90
RDP_WAIT_INTERVAL=2
```

Tối đa khoảng:

```text
90 × 2 = 180 giây
≈ 3 phút
```

---

# 36. Cài đặt script

Giả sử file script tên:

```text
install.sh
```

Cấp quyền thực thi:

```bash
chmod +x install.sh
```

Chạy:

```bash
./install.sh
```

Hoặc:

```bash
bash install.sh
```

---

# 37. Khuyến nghị khi public GitHub

Không nên để repository có secret thật.

### Không nên

```bash
USERNAME="your-real-user"
PASSWORD="your-real-password"
TS_AUTH_KEY="tskey-auth-REAL-KEY"
```

### Nên

```bash
USERNAME="${WINDOWS_USERNAME:?Windows username is required}"
PASSWORD="${WINDOWS_PASSWORD:?Windows password is required}"
TS_AUTH_KEY="${TS_AUTH_KEY:?Tailscale Auth Key is required}"
```

Sau đó:

```bash
export WINDOWS_USERNAME="..."
export WINDOWS_PASSWORD="..."
export TS_AUTH_KEY="..."
```

và chạy:

```bash
./install.sh
```

---

# 38. `.gitignore` đề xuất

Tạo file `.gitignore`:

```gitignore
.env
*.env
*.key
*.secret
secrets/
credentials/
```

Nếu dùng một file cấu hình riêng:

```text
config.local.sh
```

thì thêm:

```gitignore
config.local.sh
```

---

# 39. Cách tổ chức repository

Gợi ý:

```text
windows-server-docker/
├── README.md
├── install.sh
├── .gitignore
└── config.example.sh
```

### `install.sh`

Chứa script triển khai.

### `README.md`

Chứa hướng dẫn.

### `config.example.sh`

Chỉ chứa cấu hình mẫu, không chứa secret thật.

Ví dụ:

```bash
USERNAME="CHANGE_ME"
PASSWORD="CHANGE_ME"
TS_AUTH_KEY="PASTE_NEW_TAILSCALE_AUTH_KEY_HERE"
```

---

# 40. Kiểm tra sau khi cài

### Docker container

```bash
docker ps
```

### Container state

```bash
docker inspect windows
```

### Logs

```bash
docker logs --tail 300 windows
```

### Port

```bash
docker port windows
```

### Port 8006

```bash
ss -lntp | grep ':8006'
```

### Port 3389

```bash
ss -lntp | grep ':3389'
```

### Tailscale IP

```bash
sudo tailscale ip -4
```

### Tailscale status

```bash
sudo tailscale status
```

### Docker storage

```bash
docker volume inspect windows-storage
```

---

# 41. Truy cập Web VNC

Trên cùng host:

```text
http://127.0.0.1:8006
```

Trong GitHub Codespaces, mở:

```text
PORTS
```

và tìm:

```text
8006
```

Nếu script lấy được `browseUrl`, output cuối cùng sẽ hiển thị URL đó.

---

# 42. Truy cập RDP

Lấy Tailscale IP:

```bash
sudo tailscale ip -4
```

Ví dụ:

```text
100.100.100.100
```

Kết nối RDP:

```text
100.100.100.100:3389
```

Username dùng giá trị:

```bash
USERNAME
```

Password dùng giá trị:

```bash
PASSWORD
```

---

# 43. Xử lý lỗi thường gặp

## `/dev/kvm không tồn tại`

Lỗi:

```text
/dev/kvm không tồn tại.
```

Kiểm tra:

```bash
ls -l /dev/kvm
```

Nếu host không cung cấp KVM, container Windows có thể không chạy đúng theo cấu hình hiện tại.

---

## `/dev/net/tun không tồn tại`

Kiểm tra:

```bash
ls -l /dev/net/tun
```

Thử:

```bash
sudo mkdir -p /dev/net
sudo modprobe tun
```

---

## Docker daemon không chạy

Kiểm tra:

```bash
docker info
```

Nếu host dùng systemd:

```bash
sudo systemctl status docker
```

---

## Không đủ RAM

Script yêu cầu:

```text
15 GB RAM
```

Kiểm tra:

```bash
free -h
```

---

## Không đủ disk

Kiểm tra:

```bash
df -h /
```

Script cần ít nhất:

```text
20 GB free
```

Tùy môi trường thực tế, Windows image, cache và Docker metadata có thể còn cần thêm dung lượng.

---

## Windows container bị restart liên tục

Kiểm tra:

```bash
docker ps -a
docker inspect windows
docker logs --tail 300 windows
```

Đặc biệt kiểm tra:

```text
RAM
KVM
disk
Docker storage
```

---

## RDP CLOSED

Kiểm tra:

```bash
docker port windows
```

và:

```bash
ss -lntp | grep ':3389'
```

Sau đó kiểm tra:

```bash
docker logs --tail 300 windows
```

và Tailscale:

```bash
sudo tailscale status
sudo tailscale ip -4
```

---

## VNC chưa mở

Kiểm tra:

```bash
docker port windows
```

và:

```bash
ss -lntp | grep ':8006'
```

Kiểm tra log:

```bash
docker logs --tail 300 windows
```

---

## Không tìm thấy `vnc.html`

Script sẽ thử các đường dẫn phổ biến và sau đó dùng:

```bash
find / -type f -name "vnc.html"
```

Nếu image Dockurr thay đổi cấu trúc file, logic noVNC có thể cần cập nhật.

---

# 44. Xem thông tin cuối cùng

Cuối script, hàm:

```bash
show_connection_info()
```

hiển thị:

```text
Container
Restart
RestartCount
Guest IP
Storage
Storage used
```

Thông tin Windows:

```text
CPU
RAM MODE
RAM
RAM MAX
DISK
FORMAT
RESOLUTION
```

Thông tin VNC:

```text
Local
Clip
Scaling
Hide Clip
Hide Scale
Codespaces
```

Thông tin Tailscale:

```text
IP
```

Thông tin RDP:

```text
Address
Username
Password
Status
```

---

# 45. Các hàm chính trong script

| Hàm | Chức năng |
|---|---|
| `validate_config()` | Kiểm tra cấu hình |
| `host_cpu()` | Lấy số CPU |
| `host_ram_gb()` | Lấy tổng RAM |
| `host_available_ram_gb()` | Lấy RAM khả dụng |
| `host_free_gb()` | Lấy disk trống |
| `calculate_ram()` | Tính RAM AUTO/FIXED |
| `container_exists()` | Kiểm tra container |
| `container_running()` | Kiểm tra container đang chạy |
| `container_status()` | Lấy trạng thái container |
| `container_exit_code()` | Lấy exit code |
| `container_restart_count()` | Lấy số lần restart |
| `volume_exists()` | Kiểm tra Docker volume |
| `volume_mountpoint()` | Lấy mountpoint |
| `volume_size()` | Tính dung lượng volume |
| `check_port()` | Kiểm tra local port |
| `last_logs()` | Lấy 300 log cuối |
| `windows_ready()` | Kiểm tra Windows đã READY |
| `windows_disk_error()` | Tìm lỗi thiếu disk |
| `prepare_tailscale()` | Cài/đăng nhập Tailscale |
| `check_prereqs()` | Kiểm tra host |
| `cleanup_host_space()` | Dọn cache host |
| `clear_dockur_cache()` | Xóa Dockur cache |
| `check_disk_capacity()` | Kiểm tra disk |
| `clear_windows_all()` | Xóa Windows/Docker data theo cờ |
| `prepare_image()` | Chuẩn bị Docker image |
| `ensure_storage()` | Tạo storage |
| `create_windows()` | Tạo Windows container |
| `use_existing_windows()` | Dùng container hiện tại |
| `wait_windows()` | Chờ Windows boot |
| `find_novnc_html()` | Tìm `vnc.html` |
| `configure_novnc()` | Cấu hình noVNC |
| `wait_vnc()` | Chờ port VNC |
| `wait_rdp()` | Chờ port RDP |
| `repair_port()` | Xử lý GitHub Codespaces port |
| `show_connection_info()` | In thông tin kết nối |

---

# 46. Màu output

Script định nghĩa:

```bash
RED
GREEN
YELLOW
BLUE
CYAN
RESET
```

Các hàm:

```bash
info()
ok()
warn()
error()
section()
die()
```

giúp output dễ đọc hơn.

Ví dụ:

```text
[INFO]
[OK]
[WARN]
[ERROR]
```

---

# 47. Chính sách xử lý lỗi

Script bắt đầu với:

```bash
set -Eeuo pipefail
```

Ý nghĩa thực tế:

- `-e`: dừng khi command thất bại nếu không được xử lý.
- `-u`: lỗi khi sử dụng biến chưa được khai báo.
- `-o pipefail`: pipeline trả lỗi nếu một command trong pipeline lỗi.

Các bước có thể thất bại nhưng không cần dừng toàn bộ script thường được bao quanh bằng:

```bash
|| true
```

Ví dụ dọn cache:

```bash
sudo apt-get clean >/dev/null 2>&1 || true
```

---

# 48. Ghi chú về môi trường Codespaces

Script đang có các biến và đường dẫn liên quan đến GitHub Codespaces, ví dụ:

```text
CODESPACE_NAME
/home/codespace/windows
gh codespace ports
```

Do đó README này mô tả đầy đủ logic hiện tại của script, nhưng khi chạy trên một Linux server VPS riêng, bạn nên kiểm tra lại:

```text
/home/codespace/windows
gh
CODESPACE_NAME
```

Nếu không sử dụng Codespaces, phần `repair_port()` có thể tự bỏ qua phần xử lý Codespaces.

---

# 49. Quy trình cài mới hoàn toàn

Đây là chế độ destructive.

Cấu hình:

```bash
CLEAR_WINDOWS="ON"
FORCE_REINSTALL="ON"
REMOVE_WINDOWS_IMAGE="ON"
```

Chạy:

```bash
./install.sh
```

Luồng:

```text
Stop Windows
   ↓
Remove Windows container
   ↓
Remove windows-storage
   ↓
Docker prune
   ↓
Remove Docker image
   ↓
Clear Dockur cache
   ↓
Clean host cache
   ↓
Check disk
   ↓
Pull image mới
   ↓
Create storage
   ↓
Create Windows Server 2022
   ↓
Wait Windows READY
   ↓
Configure noVNC
   ↓
Check VNC
   ↓
Check RDP
   ↓
Show connection info
```

---

# 50. Quy trình giữ Windows hiện tại

Cấu hình:

```bash
CLEAR_WINDOWS="OFF"
FORCE_REINSTALL="OFF"
```

Script sẽ:

```text
Giữ container
Giữ storage
Giữ Dockur cache
Không dọn Docker
```

Nếu container đã tồn tại nhưng stopped:

```bash
docker start windows
```

sau đó tiếp tục chờ Windows.

---

# 51. Phiên bản script hiện tại

Các giá trị quan trọng của phiên bản script được cung cấp:

```text
Windows Server: 2022
Image: dockurr/windows:latest
CPU: max
RAM: AUTO, 4G–10G
Reserve host RAM: 1G
Disk: 20G qcow2
VNC: 8006
RDP: 3389
Storage: windows-storage
Auto restart: ON
KVM: ON
HV: ON
```

---

# 52. License và nguồn

Script sử dụng Docker image:

```text
dockurr/windows:latest
```

Bạn nên tự kiểm tra license, điều khoản sử dụng và yêu cầu bản quyền của:

- Windows Server
- Docker
- Dockurr Windows image
- Tailscale
- noVNC

README này chỉ mô tả cách script được cấu hình và hoạt động; việc sử dụng phần mềm bên thứ ba phải tuân thủ license/terms tương ứng.

---

# 53. Checklist trước khi chạy

```text
[ ] Đã cài Docker
[ ] Docker daemon đang chạy
[ ] Có /dev/kvm
[ ] Có /dev/net/tun
[ ] Có ít nhất 2 CPU
[ ] Có ít nhất 15 GB RAM
[ ] Có ít nhất 20 GB disk trống
[ ] Có sudo
[ ] Có curl
[ ] Đã thay Windows username/password
[ ] Đã thay Tailscale Auth Key
[ ] Không commit secret thật lên GitHub
[ ] Hiểu rằng CLEAR_WINDOWS=ON có thể xóa dữ liệu
[ ] Hiểu rằng Docker prune có thể ảnh hưởng resource Docker khác
```

---

# 54. Lệnh kiểm tra nhanh trước khi chạy

```bash
docker info
nproc
free -h
df -h /
ls -l /dev/kvm
ls -l /dev/net/tun
curl --version
sudo -v
```

Tailscale:

```bash
command -v tailscale
sudo tailscale status
```

---

# 55. Kết luận

Script này được thiết kế theo mô hình:

```text
Docker
  +
Windows Server 2022
  +
KVM/HV
  +
Docker persistent volume
  +
Tailscale
  +
Web noVNC
  +
RDP
  +
Auto restart
  +
Automated health/wait checks
```

Điểm quan trọng nhất khi đưa project lên GitHub là **tách secret ra khỏi source code**. Không đưa Windows password hoặc Tailscale Auth Key thật vào repository public.

---

## Quick Start

```bash
git clone <YOUR_REPOSITORY>
cd <YOUR_REPOSITORY>

chmod +x install.sh

export WINDOWS_USERNAME="your-user"
export WINDOWS_PASSWORD="your-password"
export TS_AUTH_KEY="your-new-tailscale-auth-key"

./install.sh
```

Sau khi script hoàn tất:

```text
Web VNC:
http://127.0.0.1:8006
```

RDP:

```text
<TAILSCALE_IP>:3389
```
