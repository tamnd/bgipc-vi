<!-- Beej's guide to IPC

# vim: ts=4:sw=4:nosi:et:tw=72
-->

<!-- ======================================================= -->
<!-- Pipes -->
<!-- ======================================================= -->

# Pipes (Đường ống) {#pipes}

Không có hình thức IPC nào đơn giản hơn pipe. Được triển khai trên mọi
hương vị Unix, `pipe()` và [`fork()`](#fork) tạo nên chức năng đằng sau
"`|`" trong "`ls | more`". Chúng hữu ích một cách vừa phải cho những thứ
hay ho, nhưng là cách học tốt về các phương pháp IPC cơ bản.

Vì chúng quá quá dễ, tôi sẽ không dành nhiều thời gian cho chúng. Chúng
ta sẽ chỉ xem qua vài ví dụ.

## "Những cái pipe này sạch đấy!"

Đợi đã! Không nhanh vậy. Tôi có thể cần định nghĩa "file descriptor" ở
điểm này. Để tôi nói thế này: bạn biết về "`FILE*`" từ `stdio.h` chứ?
Bạn biết cách bạn có tất cả những hàm hay ho như `fopen()`, `fclose()`,
`fwrite()`, v.v.? Thực ra, những hàm đó là các hàm cấp cao được triển
khai bằng _file descriptor_, sử dụng các system call như `open()`,
`creat()`, `close()`, và `write()`. File descriptor đơn giản là các
`int` tương tự với `FILE*` trong `stdio.h`.

Ví dụ, `stdin` là file descriptor "0", `stdout` là "1", và `stderr` là
"2". Tương tự, bất kỳ file nào bạn mở bằng `fopen()` đều có file
descriptor riêng, mặc dù chi tiết này bị ẩn khỏi bạn. (File descriptor
này có thể được lấy từ `FILE*` bằng cách dùng macro `fileno()` từ
`stdio.h`.)

![Cách một pipe được tổ chức.](pipe1.pdf "[How a pipe is organized]")

Về cơ bản, một lần gọi hàm `pipe()` trả về một cặp file descriptor. Một
trong số các descriptor này được kết nối với đầu ghi của pipe, và cái kia
được kết nối với đầu đọc. Bất cứ thứ gì có thể được ghi vào pipe, và đọc
từ đầu kia theo thứ tự nó đến. Trên nhiều hệ thống, pipe sẽ đầy sau khi
bạn ghi khoảng 10K vào chúng mà không đọc gì ra.

Như một [flx[ví dụ vô dụng|pipe1.c]], chương trình sau tạo, ghi vào, và
đọc từ một pipe.

``` {.c .numberLines}
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <unistd.h>

int main(void)
{
    int pfds[2];
    char buf[30];

    if (pipe(pfds) == -1) {
        perror("pipe");
        exit(1);
    }

    printf("writing to file descriptor #%d\n", pfds[1]);
    write(pfds[1], "test", 5);
    printf("reading from file descriptor #%d\n", pfds[0]);
    read(pfds[0], buf, 5);
    printf("read \"%s\"\n", buf);

    return 0;
}
```

Như bạn có thể thấy, `pipe()` nhận một mảng hai `int` làm đối số. Giả
sử không có lỗi, nó kết nối hai file descriptor và trả về chúng trong
mảng. Phần tử đầu tiên của mảng là đầu đọc của pipe, phần tử thứ hai
là đầu ghi.

## `fork()` và `pipe()`---bạn có quyền lực!

Từ ví dụ trên, khá khó thấy những thứ này có thể hữu ích như thế nào.
Thực ra, vì đây là tài liệu IPC, hãy đưa `fork()` vào và xem điều gì xảy
ra. Giả sử bạn là một đặc vụ liên bang hàng đầu được giao nhiệm vụ làm
cho một tiến trình con gửi từ "test" đến tiến trình cha. Không hào
hứng lắm, nhưng không ai bảo rằng khoa học máy tính sẽ là X-Files,
Mulder.

Đầu tiên, chúng ta sẽ để tiến trình cha tạo một pipe. Thứ hai, chúng ta
sẽ `fork()`. Giờ, trang man `fork()` cho biết rằng tiến trình con sẽ
nhận được bản sao của tất cả file descriptor của cha, và điều này bao
gồm bản sao của các file descriptor của pipe. _Alors_, tiến trình con
sẽ có thể gửi thứ gì đó đến đầu ghi của pipe, và tiến trình cha sẽ nhận
nó từ đầu đọc. [flx[Như thế này|pipe2.c]]:

``` {.c .numberLines}
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/types.h>
#include <unistd.h>

int main(void)
{
    int pfds[2];
    char buf[30];

    pipe(pfds);

    if (!fork()) {
        printf(" CHILD: writing to the pipe\n");
        write(pfds[1], "test", 5);
        printf(" CHILD: exiting\n");
        exit(0);
    } else {
        printf("PARENT: reading from pipe\n");
        read(pfds[0], buf, 5);
        printf("PARENT: read \"%s\"\n", buf);
        wait(NULL);
    }

    return 0;
}
```

Xin lưu ý, chương trình của bạn nên có nhiều kiểm tra lỗi hơn của tôi.
Tôi đôi khi bỏ qua nó để giúp mọi thứ rõ ràng hơn.

Dù sao, ví dụ này giống như ví dụ trước, ngoại trừ bây giờ chúng ta
`fork()` ra một tiến trình mới và để nó ghi vào pipe, trong khi tiến
trình cha đọc từ nó. Kết quả đầu ra sẽ tương tự như sau:

``` {.default}
PARENT: reading from pipe
 CHILD: writing to the pipe
 CHILD: exiting
PARENT: read "test"
```

Trong trường hợp này, tiến trình cha cố đọc từ pipe trước khi tiến
trình con ghi vào đó. Khi điều này xảy ra, tiến trình cha được gọi là
_block_, hay ngủ, cho đến khi dữ liệu đến để đọc. Có vẻ tiến trình cha
đã cố đọc, đi ngủ, tiến trình con ghi và thoát, và tiến trình cha thức
dậy và đọc dữ liệu.

Hoan hô!! Bạn vừa thực hiện một số giao tiếp liên tiến trình! Đơn giản
đến mức kinh hoàng phải không? Tôi cá là bạn vẫn đang nghĩ rằng không
có nhiều ứng dụng cho `pipe()` và, thực ra, bạn có thể đúng. Các hình
thức IPC khác thường hữu ích hơn và thường thú vị hơn.

## Tìm kiếm Pipe như chúng ta biết

Trong nỗ lực khiến bạn nghĩ rằng pipe thực sự là những thú đáng tin
cậy, tôi sẽ cho bạn một ví dụ về việc sử dụng `pipe()` trong một tình
huống quen thuộc hơn. Thử thách: triển khai "`ls | wc -l`" trong C.

Điều này yêu cầu sử dụng thêm một vài hàm mà bạn có thể chưa từng nghe
đến: `exec()` và `dup()`. Họ hàm `exec()` thay thế tiến trình đang chạy
hiện tại bằng tiến trình nào đó được truyền vào `exec()`. Đây là hàm
chúng ta sẽ dùng để chạy `ls` và `wc -l`. `dup()` nhận một file
descriptor đang mở và tạo một bản sao (bản nhân đôi) của nó. Đây là
cách chúng ta sẽ kết nối standard output của `ls` với standard input của
`wc`. Thấy đó, stdout của `ls` chảy vào pipe, và stdin của `wc` chảy vào
từ pipe. Pipe nằm ngay ở giữa!

Dù sao, [flx[đây là code|pipe3.c]]:

``` {.c .numberLines}
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(void)
{
    int pfds[2];

    pipe(pfds);

    if (!fork()) {
        close(1);       /* close normal stdout */
        dup(pfds[1]);   /* make stdout same as pfds[1] */
        close(pfds[0]); /* we don't need this */
        execlp("ls", "ls", NULL);
    } else {
        close(0);       /* close normal stdin */
        dup(pfds[0]);   /* make stdin same as pfds[0] */
        close(pfds[1]); /* we don't need this */
        execlp("wc", "wc", "-l", NULL);
    }

    return 0;
}
```

Tôi sẽ ghi chú thêm về tổ hợp `close()`/`dup()` vì nó khá kỳ lạ.
`close(1)` giải phóng file descriptor 1 (standard output). `dup(pfds[1])`
tạo bản sao của đầu ghi của pipe trong file descriptor đầu tiên có sẵn,
là "1", vì chúng ta vừa đóng cái đó. Theo cách này, bất cứ thứ gì `ls`
ghi vào standard output (file descriptor 1) sẽ thay vào đó đi vào
`pfds[1]` (đầu ghi của pipe). Phần code `wc` hoạt động theo cách tương
tự, ngoại trừ ngược lại.

## Tóm tắt

Không có nhiều điều để nói về một chủ đề đơn giản như vậy. Thực ra, hầu
như chẳng có gì. Có lẽ cách dùng tốt nhất của pipe là cách bạn quen
thuộc nhất: gửi standard output của một lệnh đến standard input của lệnh
khác. Đối với các mục đích sử dụng khác, nó khá hạn chế và thường có
các kỹ thuật IPC khác hoạt động tốt hơn.
