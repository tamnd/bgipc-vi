<!-- Beej's guide to IPC

# vim: ts=4:sw=4:nosi:et:tw=72
-->

<!-- ======================================================= -->
<!-- Unix Sockets -->
<!-- ======================================================= -->

# Unix Socket {#unixsock}

Bạn còn nhớ [FIFO](#fifos) không? Bạn còn nhớ cách chúng chỉ có thể
gửi dữ liệu theo một chiều, giống như [Pipe](#pipes) không? Sẽ tuyệt
không nếu bạn có thể gửi dữ liệu theo cả hai chiều như với socket?

Vâng, đừng lo nữa, vì đây là câu trả lời: Unix Domain Socket! Trong
trường hợp bạn vẫn đang tự hỏi socket là gì, vâng, đó là một đường ống
giao tiếp hai chiều, có thể được dùng để giao tiếp qua nhiều _domain_
khác nhau. Một trong những domain phổ biến nhất mà socket giao tiếp là
Internet, nhưng ta sẽ không bàn đến điều đó ở đây. Tuy nhiên, ta sẽ nói
về socket trong domain Unix; tức là, các socket có thể được dùng giữa
các tiến trình trên cùng một hệ thống Unix.

Unix socket dùng nhiều lệnh gọi hàm giống như Internet socket, và tôi
sẽ không mô tả chi tiết tất cả các lệnh gọi tôi dùng trong tài liệu
này. Nếu mô tả về một lệnh gọi cụ thể quá mơ hồ (hoặc nếu bạn chỉ muốn
tìm hiểu thêm về Internet socket dù sao), tôi tùy tiện đề xuất
[flbg[Hướng Dẫn Lập Trình Mạng của Beej sử dụng
Internet Socket|bgnet]]. Tôi biết tác giả đó rất rõ.

## Tổng Quan

Như tôi đã nói trước đó, Unix socket giống như FIFO hai chiều. Tuy nhiên,
tất cả giao tiếp dữ liệu sẽ diễn ra qua giao diện socket, thay vì qua
giao diện file. Mặc dù Unix socket là một file đặc biệt trong hệ thống
file (giống như FIFO), bạn sẽ không dùng `open()` và `read()`---bạn sẽ
dùng `socket()`, `bind()`, `recv()`, v.v.

Khi lập trình với socket, bạn thường tạo các chương trình server và
client. Server sẽ ngồi lắng nghe các kết nối đến từ client và xử lý
chúng. Điều này rất giống với tình huống tồn tại với Internet socket,
nhưng có một số khác biệt tinh tế.

Ví dụ, khi mô tả Unix socket nào bạn muốn dùng (tức là đường dẫn đến
file đặc biệt là socket), bạn dùng `struct sockaddr_un`, có các trường
sau:

```
struct sockaddr_un {
    unsigned short sun_family;  /* AF_UNIX */
    char sun_path[108];
}
```

Đây là cấu trúc bạn sẽ truyền vào hàm `bind()`, hàm liên kết một socket
descriptor (một file descriptor) với một file nhất định (tên của file đó
nằm trong trường `sun_path`).

## Các Bước Để Là Server

Không đi vào quá nhiều chi tiết, tôi sẽ phác thảo các bước một chương
trình server thường phải thực hiện. Trong khi đó, tôi sẽ cố triển khai
một "echo server" chỉ đơn giản là echo lại mọi thứ nó nhận được trên
socket.

Đây là các bước của server:

1. **Gọi `socket()`:** Một lệnh gọi `socket()` với các đối số đúng sẽ
   tạo Unix socket:

   ``` {.c}
   unsigned int s, s2;

   struct sockaddr_un remote, local = {
       .sun_family = AF_UNIX,
       // .sun_path = SOCK_PATH,   // Can't do assignment to an array
   };

   int len;

   s = socket(_AF_UNIX_, SOCK_STREAM, 0);
   ```

   Đối số thứ hai, `SOCK_STREAM`, cho `socket()` biết tạo một stream
   socket. Vâng, datagram socket (`SOCK_DGRAM`) được hỗ trợ trong domain
   Unix, nhưng tôi chỉ đề cập đến stream socket ở đây. Những ai tò mò,
   hãy xem [flbg[Hướng Dẫn Lập Trình Mạng của Beej|bgnet]] để có mô tả
   tốt về unconnected datagram socket áp dụng hoàn hảo cho Unix socket.
   Điều duy nhất thay đổi là bạn đang dùng `struct sockaddr_un` thay vì
   `struct sockaddr_in`.

   Thêm một lưu ý: tất cả các lệnh gọi này trả về `-1` khi lỗi và đặt
   biến toàn cục `errno` để phản ánh những gì đã xảy ra. Hãy đảm bảo
   kiểm tra lỗi.

2. **Gọi `bind()`:** Bạn đã lấy được socket descriptor từ lệnh gọi
   `socket()`, bây giờ bạn muốn bind nó vào một địa chỉ trong domain
   Unix. (Địa chỉ đó, như tôi đã nói trước đây, là một file đặc biệt
   trên đĩa.)

   ``` {.c}
   strcpy(local.sun_path, "/home/beej/mysocket");
   unlink(local.sun_path);
   len = strlen(local.sun_path) + sizeof(local.sun_family);

   bind(s, (struct sockaddr *)&local, len);
   ```

   Lệnh này liên kết socket descriptor "`s`" với địa chỉ Unix socket
   "`/home/beej/mysocket`". Lưu ý rằng ta đã gọi `unlink()` trước
   `bind()` để xóa socket nếu nó đã tồn tại. Bạn sẽ nhận lỗi `EINVAL`
   nếu file đó đã có ở đó.

3. **Gọi `listen()`:** Lệnh này hướng dẫn socket lắng nghe các kết nối
   đến từ các chương trình client:

   ```
   listen(s, 5);
   ```

   Đối số thứ hai, `5`, là số kết nối đến có thể được xếp hàng đợi trước
   khi bạn gọi `accept()` bên dưới. Nếu có nhiều kết nối đang chờ được
   chấp nhận như vậy, các client thêm sẽ tạo ra lỗi `ECONNREFUSED`.

4. **Gọi `accept()`:** Lệnh này sẽ chấp nhận một kết nối từ client. Hàm
   này trả về _một socket descriptor khác_! Descriptor cũ vẫn đang lắng
   nghe các kết nối mới, nhưng cái mới này được kết nối với client:

   ``` {.c}
   len = sizeof(remote);
   s2 = accept(s, &remote, &len);
   ```

   Khi `accept()` trả về, biến `remote` sẽ được điền với `struct
   sockaddr_un` phía bên kia, và `len` sẽ được đặt thành độ dài của nó.
   Descriptor `s2` được kết nối với client, và sẵn sàng cho `send()` và
   `recv()`, như được mô tả trong [flbg[Hướng Dẫn Lập Trình Mạng|bgnet]].


5. **Xử lý kết nối và quay lại `accept()`:** Thường bạn sẽ muốn giao tiếp
   với client ở đây (ta chỉ echo lại mọi thứ nó gửi cho ta), đóng kết
   nối, rồi `accept()` một cái mới.

   ``` {.c}
   while (len = recv(s2, &buf, 100, 0), len > 0)
       send(s2, &buf, len, 0);

   /* loop back to accept() from here */
   ```

6. **Đóng kết nối:** Bạn có thể đóng kết nối bằng cách gọi `close()`,
   hoặc bằng cách gọi [flm[`shutdown`|shutdown.2]].

Sau tất cả những điều đó, đây là một số code cho echo server,
[flx[`echos.c`|echos.c]]. Tất cả những gì nó làm là chờ kết nối trên
một Unix socket (có tên, trong trường hợp này, là "echo_socket").

``` {.c .numberLines}
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#define SOCK_PATH "echo_socket"

int main(void)
{
    int s, s2, len;
    struct sockaddr_un remote, local = {
            .sun_family = AF_UNIX,
            // .sun_path = SOCK_PATH,   // Can't do assignment to an array
    };
    char str[100];

    if ((s = socket(AF_UNIX, SOCK_STREAM, 0)) == -1) {
            perror("socket");
            exit(1);
    }

    strcpy(local.sun_path, SOCK_PATH);
    unlink(local.sun_path);
    len = strlen(local.sun_path) + sizeof(local.sun_family);
    if (bind(s, (struct sockaddr *)&local, len) == -1) {
            perror("bind");
            exit(1);
    }

    if (listen(s, 5) == -1) {
            perror("listen");
            exit(1);
    }

    for(;;) {
            int done, n;
            printf("Waiting for a connection...\n");
            socklen_t slen = sizeof(remote);
            if ((s2 = accept(s, (struct sockaddr *)&remote, &slen)) == -1) {
                    perror("accept");
                    exit(1);
            }

            printf("Connected.\n");

            done = 0;
            do {
                    n = recv(s2, str, sizeof(str), 0);
                    if (n <= 0) {
                            if (n < 0) perror("recv");
                            done = 1;
                    }

                    if (!done) 
                            if (send(s2, str, n, 0) < 0) {
                                    perror("send");
                                    done = 1;
                            }
            } while (!done);

            close(s2);
    }

    return 0;
}
```

Như bạn có thể thấy, tất cả các bước đã đề cập ở trên đều có trong
chương trình này: gọi `socket()`, gọi `bind()`, gọi `listen()`, gọi
`accept()`, và thực hiện một số `send()` và `recv()` trên mạng.

## Các Bước Để Là Client

Cần có một chương trình để nói chuyện với server ở trên, phải không?
Ngoại trừ với client, nó dễ hơn nhiều vì bạn không phải làm những thứ
`listen()` và `accept()` phiền phức. Đây là các bước:

1. Gọi `socket()` để lấy một Unix domain socket để giao tiếp qua.

2. Thiết lập một `struct sockaddr_un` với địa chỉ từ xa (nơi server đang
   lắng nghe) và gọi `connect()` với nó như một đối số.

3. Giả sử không có lỗi, bạn đã kết nối với phía bên kia! Dùng `send()`
   và `recv()` tùy thích!

Thế nào về code để nói chuyện với echo server ở trên? Không vấn đề gì,
bạn bè ơi, đây là [flx[`echoc.c`|echoc.c]]:

``` {.c .numberLines}
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#define SOCK_PATH "echo_socket"

int main(void)
{
    int s, len;
    struct sockaddr_un remote = {
        .sun_family = AF_UNIX,
        // .sun_path = SOCK_PATH,   // Can't do assignment to an array
    };
    char str[100];

    if ((s = socket(AF_UNIX, SOCK_STREAM, 0)) == -1) {
        perror("socket");
        exit(1);
    }

    printf("Trying to connect...\n");

    strcpy(remote.sun_path, SOCK_PATH);
    len = strlen(remote.sun_path) + sizeof(remote.sun_family);
    if (connect(s, (struct sockaddr *)&remote, len) == -1) {
        perror("connect");
        exit(1);
    }

    printf("Connected.\n");

    /* size in fgets() includes the null byte */
    while(printf("> "), fgets(str, sizeof(str), stdin), !feof(stdin)) {
        if (send(s, str, strlen(str)+1, 0) == -1) {
            perror("send");
            exit(1);
        }

        if ((len=recv(s, str, sizeof(str)-1, 0)) > 0) {
            str[len] = '\0';
            printf("echo> %s", str);
        } else {
            if (len < 0) perror("recv");
            else printf("Server closed connection\n");
            exit(1);
        }
    }

    close(s);

    return 0;
}
```

Trong code client, tất nhiên bạn sẽ nhận thấy chỉ có một vài syscall
được dùng để thiết lập mọi thứ: `socket()` và `connect()`. Vì client sẽ
không `accept()` bất kỳ kết nối đến nào, không cần phải `listen()`. Tất
nhiên, client vẫn dùng `send()` và `recv()` để truyền dữ liệu. Đó là
tóm tắt.

## `socketpair()`---Pipe Full-Duplex Nhanh

Nếu bạn muốn một [`pipe()`](#pipes), nhưng muốn dùng một pipe duy nhất
để gửi và nhận dữ liệu từ _cả hai phía_? Vì pipe là một chiều (với
ngoại lệ trong SYSV), bạn không thể làm được! Tuy nhiên có một giải
pháp: dùng Unix domain socket, vì chúng có thể xử lý dữ liệu hai chiều.

Thật phiền phức! Thiết lập tất cả code đó với `listen()` và `connect()`
và những thứ như vậy chỉ để truyền dữ liệu theo cả hai chiều! Nhưng đoán
xem không! Bạn không cần phải làm vậy!

Đúng vậy, có một syscall tuyệt vời được gọi là `socketpair()`, đủ tốt
bụng để trả về cho bạn một cặp _socket đã được kết nối sẵn_! Không cần
thêm công việc nào từ phía bạn; bạn có thể ngay lập tức dùng các socket
descriptor này để giao tiếp liên tiến trình.

Ví dụ, hãy thiết lập hai tiến trình. Cái đầu tiên gửi một `char` đến
cái thứ hai, và cái thứ hai chuyển ký tự thành chữ hoa và trả về. Đây
là một số code đơn giản để làm chính xác điều đó, được gọi là
[flx[`spair.c`|spair.c]] (không có kiểm tra lỗi để rõ ràng hơn):

``` {.c .numberLines}
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <errno.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>

int main(void)
{
    int sv[2]; /* the pair of socket descriptors */
    char buf; /* for data exchange between processes */

    if (socketpair(AF_UNIX, SOCK_STREAM, 0, sv) == -1) {
            perror("socketpair");
            exit(1);
    }

    if (!fork()) {  /* child */
            read(sv[1], &buf, 1);
            printf("child: read '%c'\n", buf);
            buf = toupper(buf);  /* make it uppercase */
            write(sv[1], &buf, 1);
            printf("child: sent '%c'\n", buf);

    } else { /* parent */
            write(sv[0], "b", 1);
            printf("parent: sent 'b'\n");
            read(sv[0], &buf, 1);
            printf("parent: read '%c'\n", buf);
            wait(NULL); /* wait for child to die */
    }

    return 0;
}
```

Đúng là đây là một cách tốn kém để chuyển ký tự sang chữ hoa, nhưng
điều thực sự quan trọng là bạn có giao tiếp đơn giản đang diễn ra ở đây.

Một điều nữa cần lưu ý là `socketpair()` nhận cả domain (`AF_UNIX`) và
kiểu socket (`SOCK_STREAM`). Những thứ này có thể là bất kỳ giá trị hợp
lệ nào, tùy thuộc vào các thủ tục trong kernel mà bạn muốn xử lý code
của mình, và liệu bạn muốn stream hay datagram socket. Tôi chọn socket
`AF_UNIX` vì đây là tài liệu Unix socket và chúng nhanh hơn socket
`AF_INET` một chút, theo tôi nghe.

Cuối cùng, bạn có thể tò mò tại sao tôi dùng `write()` và `read()` thay
vì `send()` và `recv()`. Vâng, tóm lại, tôi đang lười biếng. Bạn thấy,
bằng cách dùng các syscall này, tôi không phải nhập đối số `flags` mà
`send()` và `recv()` dùng, và tôi luôn đặt nó thành không dù sao. Tất
nhiên, socket descriptor chỉ là file descriptor như bất kỳ cái nào khác,
vì vậy chúng phản hồi tốt với nhiều syscall thao tác file.
