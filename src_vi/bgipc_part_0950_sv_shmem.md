<!-- Beej's guide to IPC

# vim: ts=4:sw=4:nosi:et:tw=72
-->

<!-- ======================================================= -->
<!-- Shared Memory Segments -->
<!-- ======================================================= -->

# Vùng Nhớ Dùng Chung System V {#svshm}

Điều thú vị về các vùng nhớ dùng chung là chúng đúng như tên gọi: một
vùng nhớ được chia sẻ giữa các tiến trình. Ý tôi là, hãy nghĩ về tiềm
năng của điều này! Bạn có thể cấp phát một khối thông tin người chơi
cho một trò chơi nhiều người chơi và để mỗi tiến trình truy cập vào đó
tùy ý! Vui, vui, vui. (Tất nhiên, các file được ánh xạ bộ nhớ cũng làm
được điều tương tự và có thêm ưu điểm là tính bền vững, dù có những
điểm lưu ý tương tự áp dụng cho bộ nhớ dùng chung.)

Như thường lệ, có nhiều điều cần chú ý hơn, nhưng tất cả khá dễ về lâu
dài. Bạn chỉ cần kết nối vào vùng nhớ dùng chung, và lấy một con trỏ
đến vùng nhớ. Bạn có thể đọc và ghi vào con trỏ này và mọi thay đổi bạn
thực hiện sẽ hiển thị cho tất cả những người khác kết nối vào vùng. Không
có gì đơn giản hơn. Ừ thì, thực ra có, nhưng tôi chỉ đang cố làm bạn
thoải mái hơn thôi.

## Tạo Vùng và Kết Nối

Tương tự như các hình thức System V IPC khác, một vùng nhớ dùng chung
được tạo và kết nối thông qua lệnh gọi `shmget()`:

``` {.c}
int shmget(key_t key, size_t size, int shmflg);
```

Khi hoàn thành thành công, `shmget()` trả về một định danh cho vùng nhớ
dùng chung. Đối số `key` nên được tạo theo cách tương tự như được trình
bày trong tài liệu [Hàng Đợi Tin Nhắn](#svmqftok), sử dụng `ftok()`.
Đối số tiếp theo, `size`, là kích thước tính bằng byte của vùng nhớ dùng
chung. Cuối cùng, `shmflg` nên được đặt thành quyền của vùng OR theo bit
với `IPC_CREAT` nếu bạn muốn tạo vùng, nhưng có thể là `0` trong trường
hợp khác. (Không sao khi chỉ định `IPC_CREAT` mọi lúc---nó chỉ kết nối
bạn nếu vùng đã tồn tại.)

Đây là một lệnh gọi ví dụ tạo một vùng 1K với quyền `644`
(`rw-r--r--`):

``` {.c}
key_t key;
int shmid;

key = ftok("/home/beej/somefile3", 'R');
shmid = shmget(key, 1024, 0644 | IPC_CREAT);
```

(Thực tế có thể không tạo được vùng 1K, vì hệ điều hành được phép tăng
kích thước để phù hợp với bất kỳ ràng buộc nội bộ nào nó có. Ví dụ,
trên hệ thống với trang bộ nhớ ảo 4K, kích thước có khả năng sẽ được
tăng lên 4K. Tất nhiên, chương trình của bạn sẽ không biết hay quan tâm;
đây chỉ là chi tiết triển khai.)

Nhưng làm thế nào bạn lấy con trỏ tới dữ liệu đó từ handle `shmid`?
Câu trả lời nằm ở lệnh gọi `shmat()`, trong phần tiếp theo.

## Gắn Vào---Lấy Con Trỏ Đến Vùng

Trước khi bạn có thể sử dụng một vùng nhớ dùng chung, bạn phải gắn bản
thân vào nó bằng lệnh gọi `shmat()`:

``` {.c}
void *shmat(int `shmid`, void *`shmaddr`, int `shmflg`);
```

Tất cả nghĩa là gì? Vâng, `shmid` là ID bộ nhớ dùng chung bạn lấy từ
lệnh gọi `shmget()`. Tiếp theo là `shmaddr`, mà bạn có thể dùng để nói
với `shmat()` địa chỉ cụ thể nào cần dùng, nhưng bạn chỉ cần đặt nó
thành `0` và để hệ điều hành chọn địa chỉ cho bạn. Cuối cùng, `shmflg`
có thể được đặt thành `SHM_RDONLY` nếu bạn chỉ muốn đọc từ nó, `0`
trong trường hợp khác. (Xem trang man để biết các flag hữu ích khác có
thể được bao gồm.)

Đây là một ví dụ đầy đủ hơn về cách lấy con trỏ đến một vùng nhớ dùng
chung:

``` {.c}
key_t key;
int shmid;
char *data;

key = ftok("/home/beej/somefile3", 'R');
shmid = shmget(key, 1024, 0644 | IPC_CREAT);
data = shmat(shmid, (void *)0, 0);
```

Và _boom_! Bạn đã có con trỏ đến vùng nhớ dùng chung! Lưu ý rằng
`shmat()` trả về một con trỏ `void`, và ta đang xử lý nó, trong trường
hợp này, như một con trỏ `char`. Bạn có thể xử lý nó như bất cứ thứ gì
bạn muốn, tùy thuộc vào loại dữ liệu bạn có trong đó. Con trỏ đến mảng
của các cấu trúc đều được chấp nhận như bất cứ thứ gì khác.

Ngoài ra, điều thú vị cần lưu ý là `shmat()` trả về `-1` khi thất bại
(như `mmap()`). Nhưng làm thế nào bạn lấy `-1` trong một con trỏ `void`?
Chỉ cần cast trong quá trình so sánh để kiểm tra lỗi:

``` {.c}
data = shmat(shmid, (void *)0, 0);
if (data == MAP_FAILED)
    perror("shmat");
```

(Điều quan trọng cần lưu ý là số nguyên đang được cast thành con trỏ,
không phải giá trị trả về con trỏ đang được cast thành số nguyên. Đó là
sự khác biệt tinh tế, nhưng cái sau không phải lúc nào cũng khả chuyển
giữa các kiến trúc. Cũng lưu ý rằng việc cast là sang `void*` chứ không
phải `char*`, như bạn có thể mong đợi. Vì ngôn ngữ đảm bảo rằng các
cast ẩn từ `void*` sang bất kỳ loại con trỏ nào khác luôn an toàn và
đáng tin cậy, tốt hơn là dùng `void*` và để compiler làm việc.)

Tất cả những gì bạn phải làm bây giờ là thay đổi dữ liệu nó trỏ đến
theo kiểu con trỏ thông thường. Có một số mẫu trong phần tiếp theo.

## Đọc và Ghi

Giả sử bạn có con trỏ `data` từ ví dụ trên. Đó là con trỏ `char`, vì
vậy ta sẽ đọc và ghi char từ nó. Hơn nữa, để đơn giản, giả sử vùng nhớ
dùng chung 1K chứa một chuỗi kết thúc null.

Không thể đơn giản hơn. Vì đó chỉ là một chuỗi trong đó, ta có thể in
nó như thế này:

``` {.c}
printf("shared contents: %s\n", data);
```

Và ta có thể lưu thứ gì đó vào đó dễ dàng như thế này:

``` {.c}
printf("Enter a string: ");
fgets(data, 1024, stdin);
```

Tất nhiên, như tôi đã nói trước đó, bạn có thể có dữ liệu khác trong đó
chứ không chỉ `char`. Tôi chỉ dùng chúng làm ví dụ. Tôi chỉ giả định
rằng bạn đã đủ quen với con trỏ trong C để có thể xử lý bất kỳ loại dữ
liệu nào bạn nhét vào đó.

## Tách Ra Và Xóa Vùng

Khi bạn dùng xong vùng nhớ dùng chung, chương trình của bạn nên tách
bản thân ra khỏi nó bằng lệnh gọi `shmdt()` (nếu bạn không làm, điều
này sẽ tự động xảy ra khi tiến trình kết thúc):

``` {.c}
int shmdt(void *`shmaddr`);
```

Đối số duy nhất, `shmaddr`, là địa chỉ bạn lấy từ `shmat()`. Hàm trả
về `-1` khi lỗi, `0` khi thành công.

Khi bạn tách ra khỏi vùng, nó không bị hủy. Cũng không bị xóa khi _mọi
người_ tách ra khỏi nó. Bạn phải xóa nó một cách cụ thể bằng lệnh gọi
`shmctl()`, tương tự như các lệnh gọi kiểm soát cho các hàm System V IPC
khác:

``` {.c}
shmctl(shmid, IPC_RMID, NULL);
```

Lệnh gọi trên xóa vùng nhớ dùng chung, giả sử không có ai khác gắn vào
nó. Hàm `shmctl()` làm được nhiều hơn thế, và đáng để tìm hiểu. (Theo
cách riêng của bạn, tất nhiên, vì đây chỉ là tổng quan!)

Như thường lệ, bạn có thể xóa vùng nhớ dùng chung từ dòng lệnh bằng
lệnh Unix `ipcrm`. Ngoài ra, hãy đảm bảo rằng bạn không để lại bất kỳ
vùng nhớ dùng chung nào không dùng đến đang lãng phí tài nguyên hệ
thống. Tất cả các đối tượng System V IPC bạn sở hữu có thể được xem bằng
lệnh `ipcs`.

## Đồng Thời {#svshmcon}

Các vấn đề đồng thời là gì? Vâng, vì bạn có nhiều tiến trình sửa đổi
vùng nhớ dùng chung, một số lỗi có thể xảy ra khi các cập nhật vào vùng
xảy ra đồng thời. Truy cập _đồng thời_ này hầu như luôn là vấn đề khi
bạn có nhiều writer vào một đối tượng dùng chung.

Cách giải quyết là dùng [Semaphore](#svsemaphores) để khóa vùng nhớ
dùng chung trong khi một tiến trình đang ghi vào nó. (Đôi khi khóa sẽ
bao gồm cả việc đọc và ghi vào bộ nhớ dùng chung, tùy thuộc vào những
gì bạn đang làm.)

Một cuộc thảo luận thực sự về tính đồng thời nằm ngoài phạm vi của tài
liệu này, và bạn có thể muốn xem [flw[bài viết Wikipedia về vấn đề
này|Concurrency]]. Tôi chỉ để lại điều này: nếu bạn bắt đầu thấy sự
không nhất quán kỳ lạ trong dữ liệu dùng chung của mình khi bạn kết nối
hai tiến trình trở lên vào nó, rất có thể bạn đang có vấn đề đồng thời.

## Code Mẫu

Bây giờ tôi đã chuẩn bị cho bạn về tất cả các mối nguy hiểm của truy
cập đồng thời vào vùng nhớ dùng chung mà không dùng semaphore, tôi sẽ
cho bạn xem một bản demo làm chính xác điều đó. Vì đây không phải ứng
dụng quan trọng, và ít có khả năng bạn đang truy cập dữ liệu dùng chung
cùng lúc với tiến trình khác, tôi sẽ bỏ semaphore ra để đơn giản.

Chương trình này làm một trong hai điều: nếu bạn chạy nó mà không có
tham số dòng lệnh, nó in nội dung của vùng nhớ dùng chung. Nếu bạn đưa
cho nó một tham số dòng lệnh, nó lưu tham số đó vào vùng nhớ dùng chung.

Đây là code cho [flx[`shmdemo.c`|shmdemo.c]]:

``` {.c .numberLines}
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/shm.h>

#define SHM_SIZE 1024  /* make it a 1K shared memory segment */

int main(int argc, char *argv[])
{
    key_t key;
    int shmid;
    char *data;
    int mode;

    if (argc > 2) {
            fprintf(stderr, "usage: shmdemo [data_to_write]\n");
            exit(1);
    }

    /* make the key: */
    if ((key = ftok("shmdemo.c", 'R')) == -1) {
            perror("ftok");
            exit(1);
    }

    /* connect to (and possibly create) the segment: */
    if ((shmid = shmget(key, SHM_SIZE, 0644 | IPC_CREAT)) == -1) {
            perror("shmget");
            exit(1);
    }

    /* attach to the segment to get a pointer to it: */
    data = shmat(shmid, (void *)0, 0);

    /* we _could_ use MAP_FAILED, but technically that's not */
    /* the defined return value. System V failed on this one! */
    if (data == (void *)(-1)) {
            perror("shmat");
            exit(1);
    }

    /* read or modify the segment, based on the command line: */
    if (argc == 2) {
            printf("writing to segment: \"%s\"\n", argv[1]);
            strncpy(data, argv[1], SHM_SIZE);
            data[SHM_SIZE-1] = '\0';
    } else
            printf("segment contains: \"%s\"\n", data);

    /* detach from the segment: */
    if (shmdt(data) == -1) {
            perror("shmdt");
            exit(1);
    }

    return 0;
}
```

Thông thường hơn, một tiến trình sẽ gắn vào vùng và chạy một lúc trong
khi các chương trình khác đang thay đổi và đọc vùng dùng chung. Thú vị
khi xem một tiến trình cập nhật vùng và thấy các thay đổi xuất hiện với
các tiến trình khác. Một lần nữa, để đơn giản, code mẫu không làm điều
đó, nhưng bạn có thể thấy dữ liệu được chia sẻ giữa các tiến trình độc
lập như thế nào.

Ngoài ra, không có code nào ở đây để xóa vùng---hãy đảm bảo làm điều đó
khi bạn dùng xong.
