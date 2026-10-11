# Phan tich thevibe.com.vn

Nguon tham khao: https://thevibe.com.vn/

## Tong quan

Trang mau la web-app dat lich cho dich vu self photo booth, khong phai landing page marketing thuan. HTML goc cho thay ung dung dung Next.js, ngon ngu tieng Viet, title `The Vibe · Self Booth`, description `Capture the vibe of you - dat booking chup anh tu dong tai The Vibe`.

## Cau truc chinh

- Man hinh dau: form nhap so dien thoai, neu khach moi thi them ten.
- Khu showcase: danh sach phong chup, moi phong co theme/capacity rieng.
- Khu "Cach hoat dong": 4 buoc tu nhap so dien thoai, chon phong/goi, chup, ghep frame va in.
- Dashboard sau khi nhan dien khach: loi chao, nut dat booking moi, lich su booking.
- Flow booking: chon phong, chon goi, chon addon, chon thanh toan, xem tong tien.
- Trang sau booking: ma booking, trang thai thanh toan/hang doi, timeline tien trinh, gallery/print khi hoan tat.

## Phong cach UI

- Mobile-first, content width nho: khoang 440px tren mobile, 640-720px tren tablet/desktop.
- Header sticky, nen blur nhe.
- Palette am: cream, cocoa, gold, sage. Nen chinh mau kem; CTA mau nau cocoa.
- Font display serif cho logo, heading, ma booking; sans-serif Vietnamese-friendly cho body.
- Card bo goc lon, bong nhe, border mau kem dam.
- Button dang pill, uppercase, co letter spacing.
- Component lap lai: room card, choice row, receipt, status badge, timeline.

## Ban prototype trong repo

Prototype hien tai giu tinh than tren nhung dung noi dung/ten thuong hieu rieng:

- `index.html`: cau truc trang va cac section chinh.
- `styles.css`: design token, layout, responsive, card/button/timeline.
- `script.js`: tuong tac form khach hang, chon phong/goi/addon, receipt, tao booking mau.

Day la ban tinh/interactive prototype, phu hop de thay doi brand, gia, phong, payment QR va ket noi backend sau nay.
