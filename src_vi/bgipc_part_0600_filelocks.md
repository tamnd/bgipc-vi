<!-- Beej's guide to IPC

# vim: ts=4:sw=4:nosi:et:tw=72
-->

<!-- ======================================================= -->
<!-- File Locking -->
<!-- ======================================================= -->

# Khóa File {#flocking}

Khóa file cung cấp một cơ chế rất đơn giản nhưng cực kỳ hữu ích để
phối hợp các truy cập file. Trước khi tôi bắt đầu trình bày chi tiết,
hãy để tôi tiết lộ cho bạn một số bí mật về khóa file:

Có hai loại cơ chế khóa: bắt buộc (mandatory) và tư vấn (advisory).
Các hệ thống bắt buộc sẽ thực sự ngăn các lệnh `read()` và `write()`
vào file. Một số hệ thống Unix hỗ trợ chúng. Tuy nhiên, tôi sẽ bỏ qua
chúng trong toàn bộ tài liệu này, thay vào đó chỉ nói về advisory lock.
Với hệ thống advisory lock, các tiến trình vẫn có thể đọc và ghi từ
một file trong khi nó bị khóa. Vô dụng không? Không hẳn, vì có cách
để một tiến trình kiểm tra sự tồn tại của một khóa trước khi đọc hoặc
ghi. Thấy đó, đây là một loại hệ thống khóa _hợp tác_. Điều này đủ dễ
dàng cho hầu hết tất cả các trường hợp cần khóa file.

Vì điều đó đã được giải thích xong, bất cứ khi nào tôi đề cập đến khóa
từ đây trở đi trong tài liệu này, tôi đề cập đến advisory lock. Vậy thôi.

Bây giờ, hãy để tôi phân tích khái niệm khóa thêm một chút. Có hai loại
khóa (advisory!): read lock (khóa đọc) và write lock (khóa ghi) (còn
được gọi là shared lock và exclusive lock tương ứng.) Cách read lock
hoạt động là chúng không can thiệp vào các read lock khác. Ví dụ, nhiều
tiến trình có thể khóa một file để đọc cùng một lúc. Tuy nhiên, khi một
tiến trình có write lock trên một file, không có tiến trình nào khác có
thể kích hoạt read lock hoặc write lock cho đến khi nó được giải phóng.
Một cách dễ hiểu là có thể có nhiều người đọc đồng thời, nhưng chỉ có
thể có một người ghi tại một thời điểm.

Một điều cuối cùng trước khi bắt đầu: có nhiều cách để khóa file trong
các hệ thống Unix. System V thích `lockf()`, mà cá nhân tôi nghĩ là tệ.
Các hệ thống tốt hơn hỗ trợ `flock()` cung cấp kiểm soát tốt hơn đối
với khóa, nhưng vẫn còn thiếu một số cách. Để tính di động và đầy đủ,
tôi sẽ nói về cách khóa file bằng `fcntl()`. Tuy nhiên tôi khuyến khích
bạn sử dụng một trong các hàm kiểu `flock()` cấp cao hơn nếu phù hợp
với nhu cầu của bạn, nhưng tôi muốn trình bày một cách di động về toàn
bộ phạm vi quyền lực mà bạn có trong tầm tay. (Nếu hệ thống System V
Unix của bạn không hỗ trợ `fcntl()` kiểu POSIX, bạn sẽ phải đối chiếu
thông tin sau đây với trang man `lockf()` của mình.)

## Đặt khóa

Hàm `fcntl()` làm hầu như mọi thứ trên hành tinh, nhưng chúng ta sẽ
chỉ dùng nó để khóa file. Đặt khóa bao gồm điền vào một `struct flock`
(khai báo trong `fcntl.h`) mô tả loại khóa cần thiết, `open()` file với
chế độ phù hợp, và gọi `fcntl()` với các đối số thích hợp, _comme ça_:

``` {.c}
struct flock fl = {
    .l_type   = F_WRLCK,  /* F_RDLCK, F_WRLCK, F_UNLCK      */
    .l_whence = SEEK_SET, /* SEEK_SET, SEEK_CUR, SEEK_END   */
    .l_start  = 0,        /* Offset from l_whence           */
    .l_len    = 0,        /* length, 0 = to EOF             */
    // .l_pid             /* PID holding lock; F_RDLCK only */
};
int fd;

fd = open("filename", O_WRONLY);

fcntl(fd, F_SETLKW, &fl);  /* F_GETLK, F_SETLK, F_SETLKW */
```

Điều gì vừa xảy ra? Hãy bắt đầu với `struct flock` vì các trường trong
đó được dùng để _mô tả_ hành động khóa đang diễn ra. Đây là một số định
nghĩa trường:

|Trường|Mô tả|
|:------:|-------------------------------------------------------------|
|`l_type`|Đây là nơi bạn chỉ định loại khóa bạn muốn đặt. Nó là `F_RDLCK`, `F_WRLCK`, hoặc `F_UNLCK` nếu bạn muốn đặt read lock, write lock, hoặc xóa khóa, tương ứng.|
|`l_whence`|Trường này xác định điểm bắt đầu của trường `l_start` (giống như offset cho offset). Nó có thể là `SEEK_SET`, `SEEK_CUR`, hoặc `SEEK_END`, cho đầu file, vị trí file hiện tại, hoặc cuối file.|
|`l_start`|Đây là offset bắt đầu tính theo byte của khóa, tương đối với `l_whence`.|
|`l_len`|Đây là độ dài của vùng khóa tính theo byte (bắt đầu từ `l_start` tương đối với `l_whence`).|
|`l_pid`|Process ID của tiến trình đang giữ khóa. Được kernel đặt khi dùng lệnh F_RDLCK.|

Trong ví dụ của chúng ta, chúng ta nói với nó để tạo khóa loại `F_WRLCK`
(write lock), bắt đầu tương đối với `SEEK_SET` (đầu file), offset `0`,
độ dài `0` (giá trị zero có nghĩa là "khóa đến cuối file"), với PID được
đặt thành `getpid()`.

Bước tiếp theo là `open()` file, vì `flock()` cần một file descriptor
của file đang bị khóa. Lưu ý rằng khi bạn mở file, bạn cần mở nó trong
cùng _chế độ_ như bạn đã chỉ định trong khóa, như được hiển thị trong
bảng bên dưới. Nếu bạn mở file trong chế độ sai cho một loại khóa nhất
định, `fcntl()` sẽ trả về `-1` và `errno` sẽ được đặt thành `EBADF`.

|`.l_type`|Chế độ|
|:-:|-|
|`F_RDLCK`|`O_RDONLY` hoặc `O_RDWR`|
|`F_WRLCK`|`O_WRONLY` hoặc `O_RDWR`|

Cuối cùng, lệnh gọi `fcntl()` thực sự đặt, xóa, hoặc lấy khóa. Đối số
thứ hai (`cmd`) của `fcntl()` cho biết phải làm gì với dữ liệu được
truyền vào trong `struct flock`. Danh sách sau tóm tắt những gì mỗi `cmd`
của `fcntl()` thực hiện:

|`cmd`|Mô tả|
|:--------:|-------------------------------------------------------|
|`F_SETLKW`|Đối số này yêu cầu `fcntl()` cố lấy khóa được yêu cầu trong cấu trúc `struct flock`. Nếu không thể lấy khóa (vì ai đó khác đã khóa rồi), `fcntl()` sẽ đợi (block) cho đến khi khóa được giải phóng, sau đó sẽ tự đặt khóa. Đây là lệnh rất hữu ích. Tôi dùng nó mọi lúc.|
|`F_SETLK`|Hàm này gần giống với `F_SETLKW`. Sự khác biệt duy nhất là hàm này sẽ không đợi nếu không thể lấy khóa. Nó sẽ trả về ngay với `-1`. Hàm này có thể được dùng để xóa khóa bằng cách đặt trường `l_type` trong `struct flock` thành `F_UNLCK`.|
|`F_GETLK`|Nếu bạn chỉ muốn kiểm tra xem có khóa không, nhưng không muốn đặt khóa, bạn có thể dùng lệnh này. Nó tìm qua tất cả các khóa file cho đến khi tìm thấy một cái xung đột với khóa bạn chỉ định trong `struct flock`. Sau đó nó sao chép thông tin khóa xung đột vào `struct` và trả về cho bạn. Nếu không tìm thấy khóa xung đột, `fcntl()` trả về `struct` như bạn đã truyền vào, ngoại trừ đặt trường `l_type` thành `F_UNLCK`.|


Trong ví dụ trên của chúng ta, chúng ta gọi `fcntl()` với `F_SETLKW`
như đối số, vì vậy nó block cho đến khi có thể đặt khóa, rồi đặt nó
và tiếp tục.

## Xóa khóa

Ôi! Sau tất cả những thứ khóa ở trên, đã đến lúc để làm điều gì đó dễ:
mở khóa! Thực ra, điều này đơn giản hơn khi so sánh. Tôi sẽ chỉ tái sử
dụng ví dụ đầu tiên đó và thêm code để mở khóa nó ở cuối:

``` {.c}
struct flock fl = {
    .l_type   = F_WRLCK,  /* F_RDLCK, F_WRLCK, F_UNLCK      */
    .l_whence = SEEK_SET, /* SEEK_SET, SEEK_CUR, SEEK_END   */
    .l_start  = 0,        /* Offset from l_whence           */
    .l_len    = 0,        /* length, 0 = to EOF             */
    // .l_pid             /* PID holding lock; F_RDLCK only */
};
int fd;

fd = open("filename", O_WRONLY);  /* get the file descriptor */
fcntl(fd, F_SETLKW, &fl);  /* set the lock, waiting if necessary */
.
.
.
fl.l_type = F_UNLCK;     /* tell it to unlock the region */
fcntl(fd, F_SETLK, &fl); /* set the region to unlocked   */
```

Bây giờ, tôi đã để code khóa cũ trong đó để tương phản cao, nhưng bạn
có thể thấy rằng tôi chỉ thay đổi trường `l_type` thành `F_UNLCK` (để
các trường khác hoàn toàn không thay đổi!) và gọi `fcntl()` với `F_SETLK`
như lệnh. Dễ thôi!

## Một chương trình demo

Ở đây, tôi sẽ bao gồm một chương trình demo, `lockdemo.c`, đợi người
dùng nhấn return, sau đó khóa nguồn của nó, đợi một lần return khác,
rồi mở khóa. Bằng cách chạy chương trình này trong hai (hoặc nhiều hơn)
cửa sổ, bạn có thể thấy cách các chương trình tương tác trong khi đợi
khóa.

Về cơ bản, cách dùng là: nếu bạn chạy `lockdemo` mà không có đối số
dòng lệnh, nó sẽ cố lấy write lock (`F_WRLCK`) trên nguồn của nó
(`lockdemo.c`). Nếu bạn khởi động nó với bất kỳ đối số dòng lệnh nào,
nó sẽ cố lấy read lock (`F_RDLCK`) trên nó.

[flx[Đây là mã nguồn|lockdemo.c]]:

``` {.c .numberLines}
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>

int main(int argc, char *argv[])
{
        struct flock fl = {
            .l_type = F_WRLCK,
            .l_whence = SEEK_SET,
            .l_start = 0,
            .l_len = 0,
        };
    int fd;

    if (argc > 1) 
        fl.l_type = F_RDLCK;

    if ((fd = open("lockdemo.c", O_RDWR)) == -1) {
        perror("open");
        exit(1);
    }

    printf("Press <RETURN> to try to get lock: ");
    getchar();
    printf("Trying to get lock...");

    if (fcntl(fd, F_SETLKW, &fl) == -1) {
        perror("fcntl");
        exit(1);
    }

    printf("got lock\n");
    printf("Press <RETURN> to release lock: ");
    getchar();

    fl.l_type = F_UNLCK;  /* set to unlock same region */

    if (fcntl(fd, F_SETLK, &fl) == -1) {
        perror("fcntl");
        exit(1);
    }

    printf("Unlocked.\n");

    close(fd);

    return 0;
}
```

Biên dịch thằng đó lên và bắt đầu mày mò với nó trong vài cửa sổ. Lưu
ý rằng khi một `lockdemo` có read lock, các instance khác của chương
trình có thể lấy read lock của riêng chúng mà không có vấn đề gì. Chỉ
khi write lock được lấy thì các tiến trình khác mới không thể lấy khóa
bất kỳ loại nào.

Một điều nữa cần lưu ý là bạn không thể lấy write lock nếu có bất kỳ
read lock nào trên cùng vùng của file. Tiến trình đang đợi lấy write lock
sẽ đợi cho đến khi tất cả các read lock được giải phóng. Một hệ quả của
điều này là bạn có thể tiếp tục thêm read lock (vì read lock không ngăn
các tiến trình khác lấy read lock) và bất kỳ tiến trình nào đang đợi
write lock sẽ ngồi đó và chết đói. Không có quy tắc nào ở bất kỳ đâu
ngăn bạn thêm nhiều read lock hơn nếu có một tiến trình đang đợi write
lock. Bạn phải cẩn thận.

Trong thực tế, bạn có thể sẽ chủ yếu dùng write lock để đảm bảo truy
cập độc quyền vào file trong một thời gian ngắn trong khi nó đang được
cập nhật; đó là cách dùng phổ biến nhất của khóa theo những gì tôi đã
thấy. Và tôi đã thấy tất cả...thực ra tôi đã thấy một cái...một cái nhỏ
...một hình ảnh---thực ra tôi đã nghe về chúng.

## Tóm tắt

Khóa thật tuyệt. Đôi khi, tuy nhiên, bạn có thể cần kiểm soát nhiều hơn
đối với các tiến trình trong một tình huống nhà sản xuất-người tiêu thụ.
Vì lý do này, nếu không có lý do nào khác, bạn nên xem tài liệu về
[semaphore](#svsemaphores) System V (hoặc POSIX, thực ra; chúng không
giống nhau) nếu hệ thống của bạn hỗ trợ loài thú đó. Chúng cung cấp một
tương đương mở rộng hơn và ít nhất là ngang bằng về chức năng với file
lock.
