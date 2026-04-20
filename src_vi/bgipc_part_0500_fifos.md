<!-- Beej's guide to IPC

# vim: ts=4:sw=4:nosi:et:tw=72
-->

<!-- ======================================================= -->
<!-- FIFOs -->
<!-- ======================================================= -->

# FIFOs {#fifos}

Một FIFO ("First In, First Out", đọc là "Fy-Foh") đôi khi còn được biết
đến là _named pipe_ (pipe có tên). Tức là, nó giống như một [pipe](#pipes),
ngoại trừ nó có tên! Trong trường hợp này, tên đó là tên của một file
mà nhiều tiến trình có thể `open()` và đọc ghi vào.

Khía cạnh sau này của FIFO được thiết kế để khắc phục một trong những
nhược điểm của pipe thông thường: bạn không thể nắm lấy một đầu của
pipe thông thường được tạo bởi một tiến trình không liên quan. Thấy đó,
nếu tôi chạy hai bản sao riêng lẻ của một chương trình, chúng đều có
thể gọi `pipe()` bao nhiêu tùy thích mà vẫn không thể nói chuyện với
nhau. (Đây là vì bạn phải `pipe()`, rồi `fork()` để có một tiến trình
con có thể giao tiếp với cha thông qua pipe.) Tuy nhiên, với FIFO, mỗi
tiến trình không liên quan chỉ cần `open()` pipe và truyền dữ liệu qua
đó.

## Một FIFO Mới Ra Đời

Vì FIFO thực sự là một file trên đĩa, bạn phải làm một số thứ cầu kỳ
để tạo nó. Không khó lắm. Bạn chỉ cần gọi `mkfifo()` với các đối số
thích hợp. Đây là một lệnh gọi `mkfifo()` tạo ra một FIFO:

``` {.c}
mkfifo("myfifo", 0644);
```

Trong ví dụ trên, file FIFO sẽ được gọi là "`myfifo`". Đối số thứ hai
đặt quyền truy cập cho file đó (octal 644, hay `rw-r--r--`) cũng có thể
được đặt bằng cách OR các macro từ `sys/stat.h`. Quyền này giống như
quyền bạn sẽ đặt bằng lệnh `chmod`.

(Ghi chú thêm: một FIFO cũng có thể được tạo từ dòng lệnh bằng lệnh
Unix `mkfifo`.)

### Ghi chú Lịch sử: `mknod`

Cách gốc để tạo một FIFO là với `mknod()`, nhưng cách này đã bị loại bỏ.
Hiện tại, hai lệnh gọi này là tương đương:

``` {.c}
mknod("myfifo", S_IFIFO | 0644, 0);   // old way
mkfifo("myfifo", 0644);               // new way
```
Trong trường hợp lệnh gọi `mknod()`, trước đây bạn phải làm thêm một
chút công việc bằng cách chỉ định chế độ tạo trong đối số thứ hai (OR
thêm S_IFIFO) và số thiết bị như là đối số cuối. Đối số cuối này bị bỏ
qua khi tạo FIFO, vì vậy bạn có thể đặt bất cứ thứ gì vào đó.

Nhưng bạn nên dùng `mkfifo()` để tạo FIFO nếu hệ thống của bạn hỗ trợ.

## Người sản xuất và Người tiêu thụ

Sau khi FIFO được tạo, một tiến trình có thể khởi động và mở nó để đọc
hoặc ghi bằng cách dùng system call `open()` tiêu chuẩn.

Vì tiến trình dễ hiểu hơn khi bạn có một ít code trong bụng, tôi sẽ
trình bày ở đây hai chương trình sẽ gửi dữ liệu qua FIFO. Một là
`speak.c` gửi dữ liệu qua FIFO, và cái kia được gọi là `tick.c`, vì nó
hút dữ liệu ra khỏi FIFO.

Đây là [flx[`speak.c`|speak.c]]:

``` {.c .numberLines}
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

#define FIFO_NAME "american_maid"

int main(void)
{
    char s[300];
    int num, fd;

    mkfifo(FIFO_NAME, 0644);

    printf("waiting for readers...\n");
    fd = open(FIFO_NAME, O_WRONLY);
    printf("got a reader--type some stuff\n");

    while (gets(s), !feof(stdin)) {
        if ((num = write(fd, s, strlen(s))) == -1)
            perror("write");
        else
            printf("speak: wrote %d bytes\n", num);
    }

    return 0;
}
```

`speak` làm là tạo FIFO, sau đó cố `open()` nó. Bây giờ, điều sẽ xảy ra
là lệnh gọi `open()` sẽ _block_ cho đến khi một tiến trình khác mở đầu
kia của pipe để đọc. (Có cách khắc phục điều này---xem
[`O_NDELAY`](#fifondelay), bên dưới.) Tiến trình đó là
[flx[`tick.c`|tick.c]], hiển thị ở đây:

``` {.c .numberLines}
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

#define FIFO_NAME "american_maid"

int main(void)
{
    char s[300];
    int num, fd;

    mkfifo(FIFO_NAME, 0644);

    printf("waiting for writers...\n");
    fd = open(FIFO_NAME, O_RDONLY);
    printf("got a writer\n");

    do {
        if ((num = read(fd, s, 300)) == -1)
            perror("read");
        else {
            s[num] = '\0';
            printf("tick: read %d bytes: \"%s\"\n", num, s);
        }
    } while (num > 0);

    return 0;
}
```

Giống như `speak.c`, `tick` sẽ block trên `open()` nếu không có ai ghi
vào FIFO. Ngay khi ai đó mở FIFO để ghi, `tick` sẽ bừng tỉnh.

Thử đi! Khởi động `speak` và nó sẽ block cho đến khi bạn khởi động
`tick` trong một cửa sổ khác. (Ngược lại, nếu bạn khởi động `tick`,
nó sẽ block cho đến khi bạn khởi động `speak` trong cửa sổ khác.) Gõ
thoải mái trong cửa sổ `speak` và `tick` sẽ hút hết tất cả.

Bây giờ, thoát ra khỏi `speak`. Chú ý điều gì xảy ra: `read()` trong
`tick` trả về 0, báo hiệu EOF. Theo cách này, đầu đọc có thể biết khi
nào tất cả người ghi đã đóng kết nối của họ đến FIFO. "Cái gì?" bạn hỏi
"Có thể có nhiều người ghi vào cùng một pipe không?" Tất nhiên! Điều đó
có thể rất hữu ích, bạn biết đó. Có lẽ tôi sẽ chỉ cho bạn sau trong tài
liệu này cách điều này có thể được khai thác.

Nhưng bây giờ, hãy kết thúc chủ đề này bằng cách xem điều gì xảy ra khi
bạn thoát ra khỏi `tick` trong khi `speak` đang chạy. "Broken Pipe"!
Điều đó nghĩa là gì? Thực ra, điều đã xảy ra là khi tất cả người đọc
của một FIFO đóng và người ghi vẫn còn mở, người ghi sẽ nhận signal
SIGPIPE vào lần tiếp theo nó cố `write()`. Default signal handler cho
signal này in ra "Broken Pipe" và thoát. Tất nhiên, bạn có thể xử lý
điều này lịch sự hơn bằng cách bắt SIGPIPE thông qua lệnh gọi `signal()`.

Cuối cùng, điều gì xảy ra nếu bạn có nhiều người đọc? Thực ra, những
điều kỳ lạ xảy ra. Đôi khi một trong các người đọc nhận được tất cả mọi
thứ. Đôi khi nó xen kẽ giữa các người đọc. Tại sao bạn muốn có nhiều
người đọc vậy?

## `O_NDELAY`! Tôi KHÔNG THỂ BỊ DỪNG! {#fifondelay}

Trước đó, tôi đã đề cập rằng bạn có thể khắc phục lệnh gọi `open()`
đang block nếu không có người đọc hoặc người ghi tương ứng. Cách để làm
điều này là gọi `open()` với cờ `O_NDELAY` được đặt trong đối số chế độ:

``` {.c}
fd = open(FIFO_NAME, O_WRONLY | O_NDELAY);
```

Điều này sẽ khiến `open()` trả về `-1` nếu không có tiến trình nào đang
mở file để đọc.

Tương tự, bạn có thể mở tiến trình đọc bằng cờ `O_NDELAY`, nhưng điều
này có hiệu ứng khác: tất cả các lần cố `read()` từ pipe sẽ đơn giản
trả về `0` byte đọc nếu không có dữ liệu trong pipe. (Tức là, `read()`
sẽ không còn block cho đến khi có một số dữ liệu trong pipe.) Lưu ý rằng
bạn không còn có thể biết liệu `read()` có trả về `0` vì không có dữ
liệu trong pipe, hay vì người ghi đã thoát. Đây là cái giá của quyền
lực, nhưng lời khuyên của tôi là hãy cố gắng gắn bó với blocking bất
cứ khi nào có thể.

## Xen kẽ Dữ liệu

Điều gì xảy ra nếu bạn có nhiều người ghi đang đổ dữ liệu vào pipe cùng
một lúc? Nó có thể bị xen kẽ không?

Có thể! Tùy thuộc vào lượng dữ liệu bạn đổ vào trong một lần gọi
`write()`. Miễn là bạn không vượt quá `PIPE_BUF` byte trong `write()`,
nó sẽ là atomic[^6a1b]. Và điều đó tốt!

[^6a1b]: POSIX nói `PIPE_BUF` sẽ ít nhất 512 byte. Vì vậy đó là vùng
    an toàn di động của bạn.

Điều đó nói rằng, không có gì bắt buộc rằng các lần gọi `read()` tương
ứng lấy ra từng phần dữ liệu riêng lẻ. Chúng ta có thể có điều này xảy
ra:

``` {.default}
write "Foo" 
write "bar" 
```

Và rồi một lần đọc cho chúng ta:

``` {.default}
read "Foobar" 
```

Hoặc có thể lần đọc bị ngắt!

``` {.default}
read "Foob" 
read "ar" 
```

Vì vậy ngay cả khi bạn có các lần ghi atomic, bạn sẽ cần một số cấu
trúc bổ sung ở đầu đọc để đảm bảo bạn đang lấy đúng dữ liệu ra phía
kia. Đôi khi điều này được thực hiện bằng cách thêm tiền tố dữ liệu
bằng độ dài hoặc có các tin nhắn có độ dài cố định.

Nhưng trong mọi trường hợp, bạn sẽ phải đảm bảo rằng bạn có một tin
nhắn hoàn chỉnh, hoặc bạn sẽ phải gọi `read()` lại cho đến khi có.

## Ghi chú Kết thúc

Có tên của pipe ngay trên đĩa chắc chắn làm cho mọi thứ dễ dàng hơn
phải không? Các tiến trình không liên quan có thể giao tiếp qua pipe!
(Đây là khả năng mà bạn sẽ thấy mình ước gì nếu bạn dùng pipe thông
thường quá lâu.) Dẫu vậy, chức năng của pipe có thể không hoàn toàn là
những gì bạn cần cho các ứng dụng của mình. [Hàng đợi tin nhắn](#svmq)
có thể phù hợp hơn với bạn, nếu hệ thống của bạn hỗ trợ chúng.
