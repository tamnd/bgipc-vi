<!-- Beej's guide to IPC

# vim: ts=4:sw=4:nosi:et:tw=72
-->

<!-- ======================================================= -->
<!-- Message Queues -->
<!-- ======================================================= -->

# Hàng Đợi Tin Nhắn System V {#svmq}

Những người mang lại cho chúng ta System V đã bao gồm một số tính năng
IPC tuyệt vời đã được triển khai trên nhiều nền tảng (bao gồm Linux,
tất nhiên.) Tài liệu này mô tả cách sử dụng và chức năng của Hàng Đợi
Tin Nhắn System V cực kỳ ấn tượng!

Bây giờ, trước khi bắt đầu, thông tin này đã khá *cũ*. Ừ thì, thực ra
thông tin vẫn còn tốt, nhưng có một [API hàng đợi tin nhắn POSIX mới
hơn, như mô tả trong chương trước của hướng dẫn này](#mq), phù hợp hơn
cho cuộc sống hiện đại. Nhưng có thể bạn đang dùng máy cũ hơn hoặc chỉ
muốn trải nghiệm hoài cổ. Nếu vậy, hãy đọc tiếp!

Như thường lệ, tôi muốn trình bày tổng quan trước khi đi vào chi tiết.
Một hàng đợi tin nhắn hoạt động giống như [FIFO](#fifos), nhưng hỗ trợ
thêm một số tính năng. Nhìn chung, các tin nhắn được lấy ra khỏi hàng
đợi theo thứ tự chúng được đưa vào. Tuy nhiên, cụ thể hơn, có những
cách để lấy một số tin nhắn nhất định ra khỏi hàng đợi trước khi chúng
đến lượt. Giống như chen hàng vậy. (Nhân tiện, đừng cố chen hàng khi
ghé thăm công viên giải trí Great America ở Silicon Valley, vì bạn có
thể bị bắt vì điều đó. Họ coi việc chen hàng rất _nghiêm túc_ ở đó.)

Về mặt sử dụng, một tiến trình có thể tạo một hàng đợi tin nhắn mới,
hoặc kết nối vào một hàng đợi đã có. Theo cách thứ hai này, hai tiến
trình có thể trao đổi thông tin qua cùng một hàng đợi tin nhắn. Tuyệt.

Thêm một điều về System V IPC: khi bạn tạo một hàng đợi tin nhắn, nó
không biến mất cho đến khi bạn xóa nó, giống như cách các file không
biến mất cho đến khi bạn xóa chúng một cách rõ ràng. Tất cả các tiến
trình từng sử dụng nó có thể thoát, nhưng hàng đợi vẫn tồn tại. Một
thói quen tốt là dùng lệnh `ipcs` để kiểm tra xem có hàng đợi tin nhắn
nào của bạn không dùng đang lơ lửng ở đó không. Bạn có thể xóa chúng
bằng lệnh `ipcrm`, điều này tốt hơn là để sysadmin ghé thăm và nói
rằng bạn đã chiếm hết mọi hàng đợi tin nhắn khả dụng trên hệ thống.

## Hàng Đợi Của Tôi Ở Đâu?

Hãy bắt đầu thôi! Trước tiên, bạn muốn kết nối vào một hàng đợi, hoặc
tạo nó nếu chưa tồn tại. Lệnh gọi để thực hiện điều này là syscall
`msgget()`:

``` {.c}
int msgget(key_t key, int msgflg);
```

`msgget()` trả về ID hàng đợi tin nhắn khi thành công, hoặc `-1` khi
thất bại (và nó đặt `errno`, tất nhiên.)

Các đối số có vẻ hơi kỳ lạ, nhưng có thể hiểu được sau một chút vật lộn.
Đầu tiên, `key` là một định danh duy nhất trên toàn hệ thống mô tả hàng
đợi bạn muốn kết nối vào (hoặc tạo). Mọi tiến trình khác muốn kết nối
vào hàng đợi này sẽ phải dùng cùng `key`.

Đối số kia, `msgflg` cho `msgget()` biết phải làm gì với hàng đợi đó.
Để tạo một hàng đợi, trường này phải được đặt bằng `IPC_CREAT` OR theo
bit với các quyền cho hàng đợi này. (Quyền hàng đợi giống như quyền
file Unix tiêu chuẩn---hàng đợi nhận user-id và group-id của chương
trình tạo ra chúng.)

Một lệnh gọi mẫu được đưa ra trong phần sau.

## "Anh có phải người giữ Key không?" {#svmqftok}

Chuyện về `key` này là gì vậy? Làm thế nào để tạo một cái? Vâng, vì
kiểu `key_t` thực ra chỉ là một `long`, bạn có thể dùng bất kỳ số nào
bạn muốn. Nhưng nếu bạn hardcode số đó và một chương trình khác không
liên quan cũng hardcode cùng số đó nhưng muốn một hàng đợi khác thì
sao? Giải pháp là dùng hàm `ftok()` tạo ra một key từ hai đối số:

``` {.c}
key_t ftok(const char *`path`, int `id`);
```

OK, điều này đang trở nên kỳ lạ. Về cơ bản, `path` chỉ cần là đường
dẫn đến một file xác định duy nhất ứng dụng này; đường dẫn đến file cấu
hình của ứng dụng là một chuỗi thường được dùng (khả năng nào hai ứng
dụng sẽ dùng cùng file cấu hình?). Đối số kia, `id` thường chỉ được đặt
thành một ký tự tùy ý, như 'A'. Hàm `ftok()` dùng thông tin về file đã
đặt tên (như số inode, v.v.) và `id` để tạo ra một `key` có thể là duy
nhất cho `msgget()`. Các chương trình muốn dùng cùng hàng đợi phải tạo
ra cùng `key`, vì vậy chúng phải truyền cùng tham số vào `ftok()`.

Cuối cùng, đến lúc thực hiện lệnh gọi:

``` {.c}
#include <sys/msg.h>

key = ftok("/home/beej/somefile", 'b');
msqid = msgget(key, 0666 | IPC_CREAT);
```

Trong ví dụ trên, tôi đặt quyền trên hàng đợi thành `666` (hoặc
`rw-rw-rw-`, nếu điều đó dễ hiểu hơn với bạn). Và bây giờ ta có `msqid`
sẽ được dùng để gửi và nhận tin nhắn từ hàng đợi.

## Gửi Vào Hàng Đợi

Sau khi bạn đã kết nối vào hàng đợi tin nhắn bằng `msgget()`, bạn đã
sẵn sàng gửi và nhận tin nhắn. Đầu tiên, việc gửi:

Mỗi tin nhắn gồm hai phần, được định nghĩa trong cấu trúc mẫu `struct
msgbuf`, như định nghĩa trong `sys/msg.h`:

``` {.c}
struct msgbuf {
    long mtype;
    char mtext[1];
};
```

Trường `mtype` được dùng sau này khi lấy tin nhắn từ hàng đợi, và có
thể được đặt thành bất kỳ số dương nào. `mtext` là dữ liệu sẽ được thêm
vào hàng đợi.

"Cái gì?! Bạn chỉ có thể đưa mảng một byte lên hàng đợi tin nhắn thôi
sao?! Vô dụng!!" Vâng, không hẳn vậy. Bạn có thể dùng bất kỳ cấu trúc
nào bạn muốn để đưa tin nhắn vào hàng đợi, miễn là phần tử đầu tiên là
một long. Ví dụ, ta có thể dùng cấu trúc này để lưu trữ đủ loại thứ:

``` {.c}
struct pirate_msgbuf {
    long mtype;  /* must be positive */
    struct pirate_info {
        char name[30];
        char ship_type;
        int notoriety;
        int cruelty;
        int booty_value;
    } info;
};
```

OK, vậy làm thế nào ta truyền thông tin này vào một hàng đợi tin nhắn?
Câu trả lời rất đơn giản, các bạn ơi: chỉ cần dùng `msgsnd()`:

``` {.c}
int msgsnd(int msqid, const void *msgp,
           size_t msgsz, int msgflg);
```

`msqid` là định danh hàng đợi tin nhắn được trả về bởi `msgget()`. Con
trỏ `msgp` là con trỏ đến dữ liệu bạn muốn đưa vào hàng đợi. `msgsz`
là kích thước tính bằng byte của dữ liệu cần thêm vào hàng đợi (không
tính kích thước của phần tử `mtype`). Cuối cùng, `msgflg` cho phép bạn
đặt một số tham số flag tùy chọn, mà ta sẽ bỏ qua bây giờ bằng cách đặt
nó thành `0`.

Cách tốt nhất để lấy kích thước dữ liệu cần gửi là thiết lập đúng từ
đầu. Trường đầu tiên của `struct` phải là một `long`, như ta đã thấy. Để
an toàn và khả chuyển, chỉ nên có một trường bổ sung. Nếu bạn cần nhiều
hơn một, hãy bọc chúng vào một `struct` giống như `struct pirate_msgbuf`
ở trên.

Khi cần lấy kích thước dữ liệu cần gửi, chỉ cần lấy kích thước của
trường thứ hai:

``` {.c}
struct cheese_msgbuf {
    long mtype;
    char name[20];
};

/* calculate the size of the data to send: */

struct cheese_msgbuf mbuf;
int size;

size = sizeof mbuf.name;

/* Or, without a declared variable: */

size = sizeof ((struct cheese_msgbuf*)0)->name;
```

Hoặc, nếu bạn có nhiều trường khác nhau, hãy đưa chúng vào một `struct`
và dùng toán tử <operator>sizeof</operator> trên đó. Điều này có thể
rất tiện lợi, vì bây giờ cấu trúc con có thể có tên để tham chiếu. Đây
là đoạn code thêm một trong các cấu trúc cướp biển của ta vào hàng đợi
tin nhắn:

``` {.c}
#include <sys/msg.h>
#include <stddef.h>

key_t key;
int msqid;
struct pirate_msgbuf pmb = {2, { "L'Olonais", 'S', 80, 10, 12035 } };

key = ftok("/home/beej/somefile", 'b');
msqid = msgget(key, 0666 | IPC_CREAT);

/* stick him on the queue */
/* struct pirate_info is the sub-structure */
msgsnd(msqid, &pmb, sizeof(struct pirate_info), 0);
```

Ngoài việc nhớ kiểm tra lỗi từ các giá trị trả về của tất cả các hàm
này, đó là tất cả những gì cần làm. Ồ, vâng: lưu ý rằng tôi tùy ý đặt
trường `mtype` thành `2` ở đó. Điều đó sẽ quan trọng trong phần tiếp
theo.

## Nhận Từ Hàng Đợi

Bây giờ ta đã có tên cướp biển đáng sợ [Francis
L'Olonais](https://beej.us/pirates/pirate_view.php?file=lolonais.jpg)
kẹt trong hàng đợi tin nhắn của ta, làm thế nào để lấy anh ta ra? Như
bạn có thể tưởng tượng, có một hàm đối xứng với `msgsnd()`: đó là
`msgrcv()`. Thật sáng tạo.

Một lệnh gọi `msgrcv()` để làm điều đó trông như thế này:

``` {.c}
#include <sys/msg.h>
#include <stddef.h>

key_t key;
int msqid;
struct pirate_msgbuf pmb; /* where L'Olonais is to be kept */

key = ftok("/home/beej/somefile", 'b');
msqid = msgget(key, 0666 | IPC_CREAT);

/* get him off the queue! */
msgrcv(msqid, &pmb, sizeof(struct pirate_info), 2, 0);
```

Có một điều mới cần lưu ý trong lệnh gọi `msgrcv()`: số `2`! Nó có
nghĩa là gì? Đây là tóm tắt của lệnh gọi:

``` {.c}
int msgrcv(int msqid, void *msgp, size_t msgsz, long msgtyp, int msgflg);
```

Số `2` ta chỉ định trong lệnh gọi là `msgtyp` được yêu cầu. Nhớ lại
rằng ta đã đặt `mtype` tùy ý thành `2` trong phần `msgsnd()` của tài
liệu này, vì vậy đó sẽ là cái được lấy ra từ hàng đợi.

Thực ra, hành vi của `msgrcv()` có thể thay đổi đáng kể bằng cách chọn
`msgtyp` là dương, âm, hoặc bằng không:

|`msgtyp`|Hiệu ứng trên `msgrcv()`|
|:------:|-------------------------------------------------------------|
|Không|Lấy tin nhắn tiếp theo trong hàng đợi, bất kể `mtype` của nó.|
|Dương|Lấy tin nhắn tiếp theo có `mtype` _bằng_ `msgtyp` đã chỉ định.|
|Âm|Lấy tin nhắn đầu tiên trong hàng đợi có trường `mtype` nhỏ hơn hoặc bằng giá trị tuyệt đối của đối số `msgtyp`.|

Vì vậy, điều thường xảy ra là bạn chỉ muốn tin nhắn tiếp theo trong
hàng đợi, bất kể `mtype` là gì. Như vậy, bạn sẽ đặt tham số `msgtyp`
thành `0`.

## Xóa Một Hàng Đợi Tin Nhắn

Đến lúc nào đó bạn sẽ phải xóa một hàng đợi tin nhắn. Như tôi đã nói
trước đó, chúng sẽ tồn tại cho đến khi bạn xóa chúng một cách rõ ràng;
điều quan trọng là bạn làm điều này để không lãng phí tài nguyên hệ
thống. OK, vậy bạn đã dùng hàng đợi tin nhắn này cả ngày, và nó đã cũ
rồi. Bạn muốn tiêu diệt nó. Có hai cách:

1. Dùng lệnh Unix `ipcs` để lấy danh sách các hàng đợi tin nhắn đã
   định nghĩa, rồi dùng lệnh `ipcrm` để xóa hàng đợi.

2. Viết một chương trình để làm điều đó cho bạn.

Thường thì lựa chọn thứ hai là phù hợp nhất, vì bạn có thể muốn chương
trình của mình dọn dẹp hàng đợi vào một lúc nào đó. Để làm điều này cần
giới thiệu thêm một hàm: `msgctl()`.

Tóm tắt của `msgctl()` là:

``` {.c}
int msgctl(int msqid, int cmd,
           struct msqid_ds *buf);
```

Tất nhiên, `msqid` là định danh hàng đợi lấy từ `msgget()`. Đối số quan
trọng là `cmd` cho `msgctl()` biết cách hành xử. Nó có thể là nhiều thứ,
nhưng ta chỉ nói về `IPC_RMID`, dùng để xóa hàng đợi tin nhắn. Đối số
`buf` có thể được đặt thành `NULL` cho mục đích của `IPC_RMID`.

Giả sử ta có hàng đợi ta đã tạo ở trên để chứa các cướp biển. Bạn có
thể xóa hàng đợi đó bằng cách gọi lệnh sau:

``` {.c}
#include <sys/msg.h>
.
.
msgctl(msqid, IPC_RMID, NULL);
```

Và hàng đợi tin nhắn không còn nữa. (Tất nhiên, kiểm tra lỗi trên các
giá trị trả về này luôn luôn phù hợp!)

<!-- ======================================================= -->
<!-- Message queues: Sample programs, anyone? -->
<!-- ======================================================= -->

## Chương Trình Mẫu, Ai Muốn Xem Không?

Để cho đầy đủ, tôi sẽ bao gồm một cặp chương trình sẽ giao tiếp bằng
hàng đợi tin nhắn. Chương trình đầu tiên, `kirk.c` thêm tin nhắn vào
hàng đợi tin nhắn, và `spock.c` lấy chúng ra.

Đây là mã nguồn cho [flx[`kirk.c`|kirk.c]]:

``` {.c .numberLines}
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/msg.h>

struct my_msgbuf {
    long mtype;
    char mtext[200];
};

int main(void)
{
    struct my_msgbuf buf;
    int msqid;
    key_t key;

    if ((key = ftok("kirk.c", 'B')) == -1) {
        perror("ftok");
        exit(1);
    }

    if ((msqid = msgget(key, 0644 | IPC_CREAT)) == -1) {
        perror("msgget");
        exit(1);
    }
    
    printf("Enter lines of text, ^D to quit:\n");

    buf.mtype = 1; /* we don't really care in this case */

    while(fgets(buf.mtext, sizeof buf.mtext, stdin) != NULL) {
        int len = strlen(buf.mtext);

        /* ditch newline at end, if it exists */
        if (buf.mtext[len-1] == '\n') buf.mtext[len-1] = '\0';

        if (msgsnd(msqid, &buf, len, 0) == -1)
            perror("msgsnd");
    }

    if (msgctl(msqid, IPC_RMID, NULL) == -1) {
        perror("msgctl");
        exit(1);
    }

    return 0;
}
```

Cách `kirk` hoạt động là nó cho phép bạn nhập các dòng văn bản. Mỗi
dòng được gói vào một tin nhắn và thêm vào hàng đợi tin nhắn. Hàng đợi
tin nhắn sau đó được đọc bởi `spock`.

Đây là mã nguồn cho [flx[`spock.c`|spock.c]]:

``` {.c .numberLines}
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/msg.h>

struct my_msgbuf {
    long mtype;
    char mtext[200];
};

int main(void)
{
    struct my_msgbuf buf;
    int msqid;
    key_t key;

    if ((key = ftok("kirk.c", 'B')) == -1) {  /* same key as kirk.c */
        perror("ftok");
        exit(1);
    }

    if ((msqid = msgget(key, 0644)) == -1) { /* connect to the queue */
        perror("msgget");
        exit(1);
    }
    
    printf("spock: ready to receive messages, captain.\n");

    for(;;) { /* Spock never quits! */
        if (msgrcv(msqid, &buf, sizeof buf.mtext, 0, 0) == -1) {
            perror("msgrcv");
            exit(1);
        }
        printf("spock: \"%s\"\n", buf.mtext);
    }

    return 0;
}
```

Lưu ý rằng `spock`, trong lệnh gọi `msgget()`, không bao gồm tùy chọn
`IPC_CREAT`. Ta để `kirk` tạo hàng đợi tin nhắn, và `spock` sẽ trả về
lỗi nếu anh ta chưa làm vậy.

Hãy chú ý điều gì xảy ra khi bạn đang chạy cả hai trong các cửa sổ
riêng biệt và bạn kill một trong hai. Cũng thử chạy hai bản sao của
`kirk` hoặc hai bản sao của `spock` để có ý tưởng về điều gì xảy ra khi
bạn có hai reader hoặc hai writer. Một bài trình diễn thú vị khác là
chạy `kirk`, nhập một loạt tin nhắn, rồi chạy `spock` và xem nó lấy tất
cả tin nhắn trong một lần. Chỉ cần nghịch ngợm với những chương trình
đồ chơi này sẽ giúp bạn hiểu những gì thực sự đang xảy ra.

## Tóm Tắt

Hàng đợi tin nhắn còn nhiều điều hơn những gì bài hướng dẫn ngắn này
có thể trình bày. Hãy chắc chắn xem trang man để biết bạn có thể làm gì
thêm, đặc biệt trong lĩnh vực `msgctl()`. Ngoài ra, còn có các tùy chọn
khác bạn có thể truyền vào các hàm khác để kiểm soát cách `msgsnd()` và
`msgrcv()` xử lý khi hàng đợi đầy hoặc trống tương ứng.
