
# Simple API Licensing System (iOS Tweak/App)

![Language](https://img.shields.io/badge/Language-PHP%20%7C%20Objective--C-blue)
![Database](https://img.shields.io/badge/Database-MySQL-orange)
![License](https://img.shields.io/badge/License-MIT-green)
![Author](https://img.shields.io/badge/Author-LDVQuang2306-red)

**EN** | A simple, lightweight license key management system designed for iOS apps or Jailbreak Tweaks.  
Includes a PHP-based Web Dashboard for administration and an Objective-C Client Library for easy integration.

**VI** | Hệ thống quản lý License Key (Key kích hoạt) đơn giản, nhẹ nhàng dành cho ứng dụng iOS hoặc Tweak (Jailbreak).  
Dự án gồm Web Dashboard quản lý (PHP) và Client Library (Objective-C) để tích hợp vào ứng dụng.

## ✨ Key Features | Tính năng chính

### 🖥️ Web Admin Dashboard

**EN**
- Modern interface: Sidebar menu, Card layout, fully responsive
- Package (Project) Management:
  - Create Package with unique Token
  - Set contact links (Telegram, Facebook, etc.) per Package
  - **Maintenance Mode**: Enable/disable remotely (clients will be notified and blocked)
- Key Management:
  - **Static Keys**: Expire on a fixed date (e.g. 31/12/2025)
  - **Dynamic Keys**: Time counted from first activation on device (e.g. 30 days from activation)
  - Limit number of devices (UUID) per key
  - Delete, monitor key status

**VI**
- Giao diện hiện đại: Sidebar menu, Card layout, Responsive
- Quản lý Package (Dự án):
  - Tạo Package với Token riêng biệt
  - Cài đặt Link liên hệ (Telegram, Facebook...) cho từng Package
  - **Chế độ bảo trì**: Bật/Tắt bảo trì từ xa (Client sẽ nhận thông báo và không thể đăng nhập)
- Quản lý Key:
  - **Key Tĩnh (Static)**: Hết hạn vào một ngày cụ thể (VD: 31/12/2025)
  - **Key Động (Dynamic)**: Thời gian tính từ lần kích hoạt đầu tiên trên thiết bị (VD: 30 ngày từ lúc nhập key)
  - Giới hạn số lượng thiết bị (UUID) cho mỗi Key
  - Xóa, theo dõi trạng thái Key

### 📱 iOS Client (Objective-C)

**EN**
- Automatic checks: Maintenance status checked on app launch
- Convenient UI:
  - Alert for key input
  - **Contact** button (shows support link if set by admin)
  - **Activate** button
- Core logic:
  - Checks device UDID
  - Validates expiration (date or days remaining)
  - Automatically saves key to `NSUserDefaults`

**VI**
- Tự động hóa: Tự động kiểm tra trạng thái bảo trì khi mở app
- UI Tiện lợi:
  - Hiển thị Alert nhập Key
  - Nút **Contact** (hiện link support nếu Admin đã cài đặt)
  - Nút **Kích hoạt**
- Logic Check:
  - Check UDID thiết bị
  - Check hạn sử dụng (Ngày hết hạn / Số ngày còn lại)
  - Tự động lưu Key vào `NSUserDefaults`

## 📂 Folder Structure | Cấu trúc thư mục

```
src/
├── webserver/          # Server-side code (upload to hosting)
│   ├── api/            # API endpoints for client
│   ├── theme/          # CSS/JS for dashboard
│   ├── index.php       # Dashboard home
│   ├── package.php     # Package management
│   ├── key.php         # Key management
│   └── config.php      # Database configuration
│
├── client/             # Client-side code (integrate into Xcode/Theos)
│   ├── HeaderAPI.h     # API URL & Token configuration
│   ├── QuangServer.mm  # Main entry point
│   └── api/
│       └── LDVQuang.mm # Core logic (Alert, Key check)
│
└── DOCS/               # Documentation
```

## 🚀 Server Installation | Cài đặt Server

**Yêu cầu / Requirements**
- PHP 7.4+
- MySQL Database

**EN Steps**
1. Create a new database (e.g. `simple_api_db`)
2. Import the SQL code in file docs
3. Upload all files in `src/webserver/` to your hosting (public_html or root)
4. Edit `config.php` with your database credentials
5. Visit `http://your-domain.com/index.php`
6. Go to **Package** → Create new → Copy the **Project Token**

**VI Các bước**
1. Tạo cơ sở dữ liệu mới (ví dụ: `simple_api_db`)
2. Import file SQL được ghi ở file docs
3. Upload toàn bộ thư mục `src/webserver/` lên hosting
4. Chỉnh sửa thông tin database trong `config.php`
5. Truy cập `http://your-domain.com/index.php`
6. Vào **Package** → Tạo mới → COPY **Project Token**

## 📲 Client Integration (iOS) | Tích hợp Client

**EN**
1. Copy `src/client/api/` folder and `HeaderAPI.h` into your Xcode/Theos project
2. Edit `HeaderAPI.h`:
```objective-c
static NSString *const kBaseAPIURL = @"http://your-domain.com/api/connect.php";
static NSString *const kPackageToken = @"YOU_TOKEN_PACKAGE";
```
3. That's it! The system auto-runs on app launch via `+load` method.

**VI**
1. Copy thư mục `src/client/api` và file `HeaderAPI.h` vào dự án
2. Chỉnh sửa `HeaderAPI.h`:
```objective-c
static NSString *const kBaseAPIURL = @"http://your-domain.com/api/connect.php";
static NSString *const kPackageToken = @"YOU_TOKEN_PACKAGE";
```
3. Xong! Client sẽ tự chạy khi app khởi động.

## 📡 API Reference

All endpoints use **GET** and return JSON.

### 1. Init (Lấy thông tin Package)

- **URL:** `/api/connect.php?action=init&token={PROJECT_TOKEN}`
- **Response (example):**
```json
{
    "status": true,
    "contact": "https://t.me/quangmodmap",
    "maintenance": 0
}
```

### 2. Check & Activate Key

- **URL:** `/api/connect.php?action=check&key={KEY}&uuid={UDID}`
- **Success Response (example):**
```json
{
    "status": true,
    "message": "Active",
    "expiry": "2026-12-31 23:59:59",
    "days_left": 365,
    "contact": "..."
}
```

## 📸 Screenshots | Ảnh chụp màn hình

*demo*

| Admin Dashboard              | App Alert                  |
|------------------------------|----------------------------|
| ![Admin](https://i.postimg.cc/mgt8wm6C/image.png) | ![App](https://i.postimg.cc/9FTGFsSS/IMG-4397.png) |

## ⚠️ Security Notes | Lưu ý bảo mật

**EN**  
This project prioritizes **simplicity** and learning. It intentionally avoids complex encryption (AES/RSA) to keep the code easy to understand and modify.  
→ **Not recommended** for high-security applications (banking, enterprise, etc.).  
Admin dashboard is currently public → add `.htaccess` auth or login page before exposing to the internet.

**VI**  
Dự án được thiết kế theo tiêu chí **đơn giản hóa**, không dùng mã hóa phức tạp để dễ học và chỉnh sửa.  
→ **Không khuyến khích** dùng cho dự án cần bảo mật cao.  
Dashboard hiện chưa có đăng nhập → nên thêm `.htaccess` hoặc trang login nếu public.

## 📄 License | Giấy phép

Released under the [MIT License](LICENSE).  
Copyright © 2026 **LDVQuang2306**
