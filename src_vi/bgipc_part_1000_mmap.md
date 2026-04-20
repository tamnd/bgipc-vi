<!-- Beej's guide to IPC

# vim: ts=4:sw=4:nosi:et:tw=72
-->

<!-- ======================================================= -->
<!-- Memory Mapped Files -->
<!-- ======================================================= -->

# File Được Ánh Xạ Bộ Nhớ {#mmap}

Có một lúc nào đó bạn muốn đọc và ghi từ và vào các file để thông tin
được chia sẻ giữa các tiến trình. Hãy nghĩ theo cách này: hai tiến trình
cùng mở một file và cùng đọc và ghi từ nó, do đó chia sẻ thông tin. Vấn
đề là, đôi khi thật phiền phức khi phải thực hiện tất cả những `fseek()`
và những thứ tương tự để di chuyển xung quanh. Sẽ dễ dàng hơn nếu bạn
có thể chỉ ánh xạ một phần của file vào bộ nhớ, và lấy một con trỏ đến
nó? Rồi bạn có thể đơn giản sử dụng phép tính số học con trỏ để lấy (và
đặt) dữ liệu trong file.

Vâng, đây chính xác là một file được ánh xạ bộ nhớ. Phần thú vị là khi
bạn thực hiện thay đổi vào bộ nhớ (bằng cách thay đổi những thứ mà con
trỏ trỏ đến), _nó thực sự thay đổi chính file đó_. Bộ nhớ đột nhiên trở
thành một cửa sổ nhìn vào file và bạn có thể thay đổi nó trực tiếp qua
cửa sổ đó.

Và nó thực sự rất dễ sử dụng nữa. Một vài lệnh gọi đơn giản, kết hợp
với một vài quy tắc đơn giản, và bạn đang ánh xạ như người điên.

## Bắt Đầu

Trước khi ánh xạ file vào bộ nhớ, bạn cần lấy một file descriptor cho
nó bằng cách sử dụng syscall `open()`:

``` {.c}
int fd;

fd = open("mapdemofile", O_RDWR);
```

Trong ví dụ này, ta đã mở file để truy cập đọc/ghi. Bạn có thể mở nó
ở bất kỳ chế độ nào bạn muốn, nhưng nó phải khớp với chế độ được chỉ
định trong tham số `prot` của lệnh gọi `mmap()` bên dưới.

Để ánh xạ bộ nhớ cho file, bạn dùng syscall `mmap()`, được định nghĩa
như sau:

``` {.c}
void *mmap(void *addr, size_t len, int prot,
           int flags, int fildes, off_t off);
```

Thật nhiều tham số! Đây là từng cái một:

|Tham số|Mô tả|
|--------|----------------------------------------------------------|
|`addr`|Đây là địa chỉ ta muốn file được ánh xạ vào. Cách tốt nhất để dùng cái này là đặt nó thành `NULL` và để hệ điều hành chọn cho bạn. Nếu bạn bảo nó dùng địa chỉ mà hệ điều hành không thích (ví dụ nếu nó không phải bội số của kích thước trang bộ nhớ ảo), nó sẽ báo lỗi.|
|`len`|Tham số này là độ dài dữ liệu ta muốn ánh xạ vào bộ nhớ. Có thể là bất kỳ độ dài nào bạn muốn. (Lưu ý: nếu `len` không phải bội số của kích thước trang bộ nhớ ảo, bạn sẽ nhận được một kích thước khối được làm tròn lên đến kích thước đó. Các byte thêm sẽ là 0, và bất kỳ thay đổi nào bạn thực hiện với chúng sẽ không sửa đổi file.)|
|`prot`|Đối số "bảo vệ" cho phép bạn chỉ định loại truy cập tiến trình này có đối với vùng được ánh xạ bộ nhớ. Đây có thể là sự kết hợp OR theo bit của các giá trị sau: `PROT_READ`, `PROT_WRITE`, và `PROT_EXEC`, lần lượt cho quyền đọc, ghi, và thực thi. Giá trị được chỉ định ở đây phải tương đương hoặc là tập con của các chế độ được chỉ định trong syscall `open()` được dùng để lấy file descriptor.|
|`flags`|Đây chỉ là các flag linh tinh có thể được đặt cho syscall. Bạn sẽ muốn đặt nó thành `MAP_SHARED` nếu bạn định chia sẻ các thay đổi của mình vào file với các tiến trình khác, hoặc `MAP_PRIVATE` trong trường hợp khác. Nếu bạn đặt nó thành cái sau, tiến trình của bạn sẽ nhận được một bản sao của vùng được ánh xạ, vì vậy bất kỳ thay đổi nào bạn thực hiện sẽ không được phản ánh trong file gốc---do đó, các tiến trình khác sẽ không thể thấy chúng. Ta sẽ không nói về `MAP_PRIVATE` ở đây, vì nó không liên quan nhiều đến IPC.|
|`fildes`|Đây là nơi bạn đặt file descriptor bạn đã mở trước đó.|
|`off`|Đây là offset trong file mà bạn muốn bắt đầu ánh xạ từ đó. Một hạn chế: offset này _phải_ là bội số của kích thước trang bộ nhớ ảo. Kích thước trang này có thể lấy bằng lệnh gọi `getpagesize()`. Lưu ý rằng các hệ thống 32-bit có thể hỗ trợ các file có kích thước không thể biểu diễn bằng số nguyên không dấu 32-bit, vì vậy kiểu này thường là kiểu 64-bit trên các hệ thống như vậy.|

Về giá trị trả về, như bạn có thể đã đoán, `mmap()` trả về `MAP_FAILED`
khi lỗi (giá trị `-1` được cast phù hợp để so sánh), và đặt `errno`.
Ngược lại, nó trả về con trỏ đến điểm bắt đầu dữ liệu được ánh xạ.

Dù sao, không dài dòng thêm nữa, ta sẽ làm một bản demo ngắn ánh xạ
"trang" thứ hai của file vào bộ nhớ. Đầu tiên ta sẽ `open()` nó để lấy
file descriptor, rồi ta sẽ dùng `getpagesize()` để lấy kích thước của
một trang bộ nhớ ảo và sử dụng giá trị này cho cả `len` và `off`. Theo
cách này, ta sẽ bắt đầu ánh xạ từ trang thứ hai, và ánh xạ trong độ dài
một trang. (Trên máy Linux của tôi, kích thước trang là 4K.)

``` {.c}
#include <unistd.h>
#include <sys/types.h>
#include <sys/mman.h>

int fd, pagesize;
char *data;

fd = open("foo", O_RDONLY);
pagesize = getpagesize();
data = mmap((void*)0, pagesize, PROT_READ, MAP_SHARED, fd, pagesize);
```

Sau khi đoạn code này chạy, bạn có thể truy cập byte đầu tiên của phần
được ánh xạ của file bằng `data[0]`. Lưu ý có nhiều phép cast kiểu xảy
ra ở đây. Ví dụ, `mmap()` trả về `void*`, nhưng ta xử lý nó như `char*`.

Ngoài ra hãy lưu ý rằng ta đã ánh xạ file `PROT_READ` nên ta có quyền
truy cập chỉ đọc. Bất kỳ nỗ lực nào ghi vào dữ liệu (`data[0] = 'B'`,
ví dụ) sẽ gây ra vi phạm phân đoạn. Mở file `O_RDWR` với `prot` được
đặt thành `PROT_READ|PROT_WRITE` nếu bạn muốn truy cập đọc-ghi vào dữ
liệu.

## Hủy Ánh Xạ File

Tất nhiên có một hàm `munmap()` để hủy ánh xạ bộ nhớ cho file:

``` {.c}
int munmap(void *addr, size_t len);
```

Hàm này đơn giản hủy ánh xạ vùng trỏ bởi `addr` (được trả về từ
`mmap()`) với độ dài `len` (giống với `len` được truyền vào `mmap()`).
`munmap()` trả về `-1` khi lỗi và đặt biến `errno`.

Sau khi bạn hủy ánh xạ file, bất kỳ nỗ lực nào truy cập dữ liệu qua con
trỏ cũ sẽ gây ra lỗi phân đoạn. Bạn đã được cảnh báo!

Một lưu ý cuối: file sẽ tự động hủy ánh xạ khi chương trình của bạn
thoát, tất nhiên.

## Đồng Thời, Lại Nữa?!

Nếu bạn có nhiều tiến trình thao tác dữ liệu trong cùng một file đồng
thời, bạn có thể gặp rắc rối. Bạn có thể phải [khóa file](#flocking)
hoặc dùng [semaphore](#svsemaphores) để điều phối truy cập vào file trong
khi một tiến trình can thiệp vào nó. Hãy xem tài liệu [Bộ Nhớ Dùng
Chung](#svshmcon) để có thêm (rất ít) thông tin về tính đồng thời.

## Một Mẫu Đơn Giản

Vâng, lại đến lúc code rồi. Tôi có ở đây một chương trình demo ánh xạ
mã nguồn của chính nó vào bộ nhớ và in byte tìm thấy ở bất kỳ offset nào
bạn chỉ định trên dòng lệnh.

Chương trình hạn chế các offset bạn có thể chỉ định trong phạm vi 0 đến
độ dài file. Độ dài file được lấy qua lệnh gọi `stat()` mà bạn có thể
chưa thấy trước đây. Nó trả về một cấu trúc đầy thông tin file, một
trường trong đó là kích thước tính bằng byte. Đơn giản thôi.

Đây là mã nguồn cho [flx[`mmapdemo.c`|mmapdemo.c]]:

``` {.c .numberLines}
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <errno.h>

int main(int argc, char *argv[])
{
    int fd;
    off_t offset;
    char *data;
    struct stat sbuf;

    if (argc != 2) {
        fprintf(stderr, "usage: mmapdemo offset\n");
        exit(1);
    }

    if ((fd = open("mmapdemo.c", O_RDONLY)) == -1) {
        perror("open");
        exit(1);
    }

    if (stat("mmapdemo.c", &sbuf) == -1) {
        perror("stat");
        exit(1);
    }


    offset = atoi(argv[1]);
    if (offset < 0 || offset > sbuf.st_size-1) {
        fprintf(stderr, "mmapdemo: offset must be in the range 0-%d\n", \
                                                          sbuf.st_size-1);
        exit(1);
    }
    
    data = mmap((caddr_t)0, sbuf.st_size, PROT_READ, MAP_SHARED, fd, 0);
    if (data == MAP_FAILED) {
        perror("mmap");
        exit(1);
    }

    printf("byte at offset %ld is '%c'\n", offset, data[offset]);

    return 0;
}
```

Đó là tất cả những gì cần làm. Biên dịch cái đó và chạy với một số dòng
lệnh như:

``` {.default}
$ mmapdemo 30
byte at offset 30 is 'e'
```

Tôi để lại cho bạn viết một số chương trình thực sự thú vị bằng syscall
này.

## Ánh Xạ Bộ Nhớ Ẩn Danh

Bạn có thể `mmap()` một vùng **không** được hỗ trợ bởi file. Đó chỉ là
một vùng nhớ được đặt về không mà bạn đột nhiên có quyền truy cập. Có
vẻ giống `malloc()`, nhưng, như ta sẽ thấy, có một điểm khác biệt quan
trọng lớn.

Có vẻ kỳ lạ khi muốn làm điều này---các thay đổi bạn thực hiện chỉ tồn
tại trong bộ nhớ và không được lưu trên đĩa---nhưng nó thực sự cung cấp
một cách hay để thiết lập bộ nhớ dùng chung giữa các tiến trình liên
quan.

> **Lưu ý rằng điều này không được POSIX hỗ trợ.** Điều đó nói, nó được
> định nghĩa trên Linux và BSD (bao gồm MacOS), vì vậy ta có độ phủ khá
> tốt trên tất cả các nền tảng phổ biến.
>
> Lưu ý #1: Một số nền tảng trước đây định nghĩa `MAP_ANON`, nhưng tôi
> nghĩ hầu hết đã chuyển sang `MAP_ANONYMOUS`. Vì vậy cái sau là lựa
> chọn khả chuyển hơn.
>
> Lưu ý #2: Một số nền tảng không quan tâm bạn chỉ định gì là file
> descriptor với các ánh xạ ẩn danh, nhưng MacOS muốn nó là `-1`, vì
> vậy hãy dùng giá trị đó.

(Một cách dùng khác cho loại `mmap()` này là nếu bạn đang viết bộ cấp
phát bộ nhớ riêng của mình tương tự `malloc()`. Trong trường hợp đó,
bạn sẽ cần lấy các khối bộ nhớ trực tiếp từ hệ điều hành, và `mmap()`
ẩn danh là một cách tuyệt vời để làm điều đó. Nhưng đó không phải IPC,
vì vậy ta sẽ không đi vào đó.)

Hãy làm một bản demo. Chương trình này sẽ:

1. Tạo một khối bộ nhớ dùng chung, ẩn danh (tức là không được hỗ trợ
   bởi file) bằng `mmap()`.
2. Fork một tiến trình con sẽ:
   * Ngủ một giây
   * In những gì có trong bộ nhớ dùng chung.
3. Tiến trình cha sẽ:
   * Lưu một chuỗi vào bộ nhớ dùng chung.
   * Đợi tiến trình con hoàn tất.
4. Sau đó cả cha và con sẽ `munmap()` bộ nhớ, giải phóng nó.

Điểm khác biệt con voi trong phòng lớn là ta không gọi `open()` ở bất
cứ đâu, và ta không có file descriptor để truyền vào `mmap()`. Ta sẽ chỉ
đặt cái đó thành `-1` và offset thành `0`.

Đây là mã nguồn cho [flx[`mmap_anon.c`|mmap_anon.c]]:

``` {.c .numberLines}
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/mman.h>

#define DATA_LEN 128 // bytes

#ifndef MAP_ANONYMOUS
#define MAP_ANONYMOUS MAP_ANON
#endif

int main(void)
{
    char *data = mmap(NULL, DATA_LEN, PROT_READ|PROT_WRITE,
                      MAP_SHARED|MAP_ANONYMOUS, -1, 0);

    if (data == NULL) {
        perror("mmap");
        return 1;
    }

    switch (fork()) {
        case -1:
            perror("fork");
            return 1;
                
        case 0:
            puts("child: sleeping");
            // Snooze so it's very likely the parent wins the race
            sleep(1);
            puts("child: reading");
            printf("child: %s\n", data);
            break;

        default:
            puts("parent: writing");
            strcpy(data, "Hello from shared memory!");
            puts("parent: waiting");
            wait(NULL);
            break;
    }

    munmap(data, 128);
}
```

"Đồng thời, lại nữa, lại nữa?!" Bạn có thể nhận thấy rằng thực sự
không có sự đồng bộ hóa nào giữa cha và con. Tôi chỉ lách qua bằng cách
để con ngủ để ta có thể khá chắc chắn rằng cha đã ghi dữ liệu xong. Điều
đó thực sự không đủ tốt theo bất kỳ nghĩa thực tế nào, vì vậy bạn có
thể phải làm thêm với semaphore hoặc thứ gì đó tương tự để có sự phối
hợp bạn cần để không có mọi thứ nổ tung.

Và thực ra, nếu bạn có quyền truy cập `pthreads`, chỉ cần dùng nó trong
trường hợp này. Mọi thứ khác chỉ là tái phát minh cái bánh xe đó.

## Nhận Xét Về Ánh Xạ Bộ Nhớ

Tôi sẽ thiếu sót nếu không chỉ ra một vài khía cạnh thú vị của việc sử
dụng file được ánh xạ trên Linux. Đầu tiên, bộ nhớ mà hệ điều hành phân
bổ để sử dụng làm bộ nhớ đệm cho dữ liệu file được ánh xạ là _cùng bộ
nhớ_ được sử dụng để thực hiện các thao tác đệm file khi các tiến trình
khác thực hiện các thao tác `read()` và `write()`! Trong khi các `read()`
và `write()` được đảm bảo là atomic bởi POSIX đến một kích thước nhất
định, điều đó sẽ bị phá vỡ khi một số tiến trình bỏ qua hoàn toàn các
hàm POSIX!

Thứ hai, vì ta đang bỏ qua các hàm POSIX đó, ta có thể đọc và ghi nội
dung buffer mà không cần quan tâm đến việc khóa bản ghi có thể được áp
dụng cho file descriptor (như đã thảo luận trong một phần trước). Thông
thường, điều này không phải là vấn đề lớn---ai sẽ dùng file được ánh xạ
bộ nhớ trong một ứng dụng trong khi dùng khóa bản ghi trong ứng dụng
khác, khi cả hai đều truy cập cùng file? Nếu file được ghi lại yêu cầu
khóa bản ghi, thì tất cả các ứng dụng nên dùng nó. Điều đó nói, không
có gì ngăn một ứng dụng sử dụng khóa đọc và ghi ta đã thảo luận trước
đó ngay trước khi cập nhật bộ nhớ thuộc về file được ánh xạ.

Thứ ba, vì ta đang bỏ qua các hàm POSIX đó (tôi nghe có vẻ như đĩa hát
bị rách không?), hệ thống không có khả năng cung cấp các chiến lược
readahead hoặc writebehind có ý nghĩa. Tính đến thời điểm viết bài này,
các phiên bản kernel Linux 4.x trở lên _có_ triển khai một thuật toán
phát hiện khi hai page fault liền nhau xảy ra trong một file được ánh xạ
bộ nhớ, và nó thực hiện một lượng readahead tối thiểu (chỉ hai trang, so
với readahead có thể cấu hình ở lớp hệ thống file, có thể lên đến 256KB).
Hoàn toàn không có writebehind, vì không có cách thực tế nào để phát
hiện khi các trang liền kề được ghi dưới các cấu hình phần cứng hiện tại.

Cuối cùng, với tất cả những điều trên, vẫn có những lý do rất hấp dẫn
để sử dụng file được ánh xạ bộ nhớ. Lý do chính là các file như vậy,
theo định nghĩa, là "bộ nhớ lưu trữ lâu dài", có nghĩa là các ứng dụng
không phải tạo các hàm `load()`/`save()` dài dòng cho dữ liệu của chúng
nếu chúng sử dụng file được ánh xạ bộ nhớ. Tuy nhiên, bất kỳ dữ liệu
nhị phân nào sẽ được ghi theo cách phụ thuộc nền tảng (như thứ tự byte)
vì vậy các file đó có thể không khả chuyển.

## Tóm Tắt

File được ánh xạ bộ nhớ có thể rất hữu ích, đặc biệt trên các hệ thống
không hỗ trợ các vùng nhớ dùng chung. Thực ra, cả hai rất giống nhau
trong hầu hết các khía cạnh. (File được ánh xạ bộ nhớ cũng được commit
vào đĩa, vì vậy đây thậm chí có thể là một lợi thế, phải không?) Với
khóa file hoặc semaphore, dữ liệu trong một file được ánh xạ bộ nhớ có
thể dễ dàng được chia sẻ giữa nhiều tiến trình.
