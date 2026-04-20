<!-- Beej's guide to IPC

# vim: ts=4:sw=4:nosi:et:tw=72
-->

# Hàng Đợi Tin Nhắn POSIX {#mq}

Ngày xưa, chúng ta chỉ có [hàng đợi tin nhắn System V](#svmq), nhưng
những người bạn tốt bụng tại [flw[POSIX|POSIX]] đã chuẩn hóa những thứ
này một phần để ta có thể sử dụng chúng một cách khả chuyển hơn.

Và vậy là hôm nay chúng ta đang ở đây trong năm huy hoàng %YEAR% và sắp
chứng kiến sức mạnh hủy diệt của trạm chiến đấu đã hoàn toàn đi vào
hoạt động. [*Tiếng thở của Darth Vader*].

Xin lỗi. Tôi bị cuốn vào rồi. Chúng ta đang làm gì thế nhỉ?

## Hàng Đợi Tin Nhắn Là Gì?

Nói chung, ta muốn có thể gửi các *tin nhắn* (những khối byte tùy ý)
vào *một cái gì đó*, và sau đó để các tiến trình khác nhận những tin
nhắn đó.

Và có lẽ ta muốn chúng được sắp xếp theo một thứ tự nào đó, chẳng hạn
*vào trước ra trước* như những thứ FIFO mà ta đã bàn đến.

May mắn thay, một queue (hàng đợi) là cấu trúc dữ liệu FIFO, và cũng
may mắn là ta có một tin nhắn muốn gửi. Tin nhắn. Hàng đợi. Hàng đợi
tin nhắn!

Vậy là ta sẽ có một (hoặc nhiều) *sender* (người gửi) đổ tin nhắn vào
hàng đợi ở một đầu, và ta sẽ có một (hoặc nhiều) *receiver* (người nhận)
đọc tin nhắn ra từ hàng đợi ở đầu kia.

## Tại Sao Dùng Cái Này?

Ta có một số ưu điểm so với FIFO thông thường. Một là các tin nhắn sẽ
không bị chia tách (xen kẽ) nếu có nhiều sender cùng gửi một lúc. (Điều
này có thể xảy ra trong FIFO với các tin nhắn lớn hơn.)

Ưu điểm khác là ta có thể gán cho các tin nhắn một _mức ưu tiên_ để
kiểm soát thứ tự chúng được giao.

Cuối cùng, giống như FIFO, các hàng đợi này có thể được tham gia hoặc
rời đi bất cứ lúc nào. Các tiến trình mới chỉ cần mở hàng đợi bằng một
tên đã được thỏa thuận trước và đều biết. Sẽ nói thêm về điều đó sau.

## Ưu Tiên

Mỗi lần bạn gửi một tin nhắn vào hàng đợi, bạn gắn kèm một _priority_
(ưu tiên) cho biết (một cách mơ hồ) tin nhắn đó nên được giao nhanh như
thế nào. Ưu tiên chỉ là một số nguyên không dấu, trong đó `0` là ưu tiên
thấp nhất, và một số nguyên lớn hơn nào đó, được chỉ định bởi
`MQ_PRIO_MAX`, là cao nhất.

Đặc tả không nêu rõ mức cao nhất ngoài giá trị macro phụ thuộc hệ thống
đó. Trang man của Linux đề xuất giữ mức ưu tiên trong khoảng 0 đến 31,
bao gồm cả hai đầu, để đảm bảo khả năng khả chuyển tối đa.

Và nếu bạn thực sự cần hơn 32 mức ưu tiên... thật ra, bạn đang xây
dựng cái gì vậy?

*Dù sao*, khi bạn nhận một tin nhắn, bạn sẽ nhận được cái được gửi với
ưu tiên cao nhất (dù nó được gửi muộn hơn các tin nhắn có ưu tiên thấp
hơn). Nếu có hai tin nhắn cùng mức ưu tiên cao nhất, chúng đấu tay đôi
với nhau đến cùng.

Không, đó không đúng. Nếu có sự ngang bằng về ưu tiên, các tin nhắn bị
buộc được lấy ra theo thứ tự chúng được gửi (FIFO).

## Xác Định Một Hàng Đợi

Hàng đợi tin nhắn được xác định bởi một _name_ (tên), là một chuỗi nên
bắt đầu bằng dấu gạch chéo (`/`) và không có dấu gạch chéo nào khác
trong đó. (Mọi thứ trở nên "phụ thuộc cài đặt" nếu bạn vi phạm những
quy tắc đó.)

Ví dụ, đây là một tên hàng đợi: `/waco_kid`. Rất thú vị. Tất cả các
chương trình muốn sử dụng hàng đợi đó phải biết tên đó từ trước để có
thể mở nó.

## Cách Tiếp Cận Tổng Quát

### Mở Hàng Đợi

Cả sender và receiver đều phải làm điều tương tự ở bước đầu: mở (kết
nối tới) hàng đợi tin nhắn. Điều này được thực hiện bằng system call
`mq_open()`. (Và ở đây bạn sẽ thấy file header `mqueue.h` mà bạn cần
cho tất cả những thứ này.)

Hàng đợi cũng được tạo ra bằng lệnh gọi này. Nếu nó chưa tồn tại và
các flag cùng đối số phù hợp được truyền vào `mq_open()`, hàng đợi sẽ
được tạo ra lúc đó.

Điều đáng chú ý ở đây là hàng đợi bạn tạo không bao giờ biến mất cho
đến khi bạn vứt máy tính đi hoặc bạn _unlink_ hàng đợi đó, tùy cái nào
đến trước. Sẽ nói thêm về unlink sau.

Hãy xem syscall này!

``` {.c}
#include <mqueue.h>
#include <fcntl.h>  // For the O_ flags

mqd_t mq_open(const char *name, int oflag, ...);
```

Bạn truyền tên vào đối số đầu tiên, ví dụ `/waco_kid`, rồi truyền một
số flag vào `oflag`. Và tùy theo flag, bạn có thể truyền thêm một số
thứ với dấu chấm lửng đáng sợ kia ở cuối.

Các flag được kết hợp bằng OR theo bit. Đầu tiên, bạn phải nói rõ muốn
mở để đọc (nhận), ghi (gửi), hay cả hai. Ngoài ra, bạn có thể yêu cầu
tạo hàng đợi nếu nó chưa tồn tại. Và bạn có thể chỉ định hàng đợi có
nên ở chế độ _blocking_ hay không. Sẽ nói thêm về điều đó sau.

|Flag|Mô tả|
|-|-|
|`O_RDONLY`|Mở chỉ để nhận|
|`O_WRONLY`|Mở chỉ để gửi|
|`O_RDWR`|Mở cho cả nhận và gửi|
|`O_CREAT`|Tạo hàng đợi nếu chưa tồn tại|
|`O_NONBLOCK`|Tạo hàng đợi không blocking|

Ví dụ:

``` {.c}
mqd_t mq = mq_open("/waco_kid", O_RDONLY);
```

Nhưng ở đây ta đến phần dấu chấm lửng! Nếu ta chỉ định `O_CREAT`, ta
có thể làm thêm nhiều thứ!

Cụ thể, ta có thể đặt quyền (ai được phép kết nối vào), điều ta làm
giống như bất kỳ quyền file Unix tiêu chuẩn nào. Trong ví dụ dưới đây,
ta dùng quyền `0644`, tức là `rw-r--r--`. Rồi tôi đặt `NULL` cho đối
số thứ tư — ta sẽ sớm thấy ý nghĩa của nó.

``` {.c}
mqd_t mqdes = mq_open("/waco_kid", O_RDONLY | O_CREAT, 0644, NULL);
```

Như vậy, lệnh đó sẽ tạo một hàng đợi tin nhắn! Và nó làm vậy với số
lượng tin nhắn tối đa và kích thước tin nhắn tối đa mặc định.

Nếu bạn muốn thứ gì đó khác so với mặc định thì sao? Bạn có thể dùng
đối số thứ tư để chỉ định bằng `struct mq_attr`.

Đây là các trường liên quan cho việc tạo hàng đợi:

``` {.c}
struct mq_attr {
    long mq_maxmsg;    // Max message count
    long mq_msgsize;   // Max message size
}
```

Bạn có thể kiểm soát số lượng tin nhắn tối đa có thể có trong hàng đợi
cùng một lúc với `mq_maxmsg`. Không có giá trị tối đa cố định trong đặc
tả, nhưng số tối đa bạn có thể chỉ định trên máy Linux của tôi là 10.
Có vẻ khá thấp, nhưng bạn phải tưởng tượng rằng kernel đang giữ tất cả
những tin nhắn này cho đến khi ai đó nhận chúng, và nó không muốn dùng
hết bộ nhớ của bạn để làm điều đó. Nếu mọi thứ hoạt động trơn tru, các
tiến trình khác sẽ tiêu thụ tin nhắn nhanh như khi bạn tạo ra chúng.

> Và, như chúng ta đều biết, *mọi thứ **luôn luôn** chạy trơn tru!*

Ngoài ra, mỗi tin nhắn không thể lớn hơn `mq_msgsize`. Lại không có
giá trị tối đa được định nghĩa, nhưng trên máy Linux của tôi là 8 KB.

> **Bạn có thể tự tìm hiểu điều này** trên Linux bằng cách xem một số
> file trong `/proc`
>
> ``` {.default}
> cat /proc/sys/fs/mqueue/msgsize_max   # max mq_msgsize
> cat /proc/sys/fs/mqueue/msg_max       # max mq_maxmsg
> cat /proc/sys/fs/mqueue/queues_max    # max queues
> ```

<!-- ` -->

Ta sẽ thấy những gì ta có thể làm thêm với `struct mq_attr` sau, bao
gồm kiểm tra xem có bao nhiêu tin nhắn trong hàng đợi.

### Gửi Thứ Gì Đó Vào Hàng Đợi

OK! Bây giờ ta đã mở và tạo hàng đợi, ta có thể gửi đồ vào nó!

``` {.c}
#include <mqueue.h>

int mq_send(mqd_t mqdes, const char *msg_ptr,
            size_t msg_len, unsigned int msg_prio);
```

Lệnh đó gửi tin nhắn trỏ bởi `msg_ptr` (có độ dài `msg_len` byte) vào
định danh hàng đợi ta lấy từ `mq_open()`. Và nó gửi với ưu tiên
`msg_prio`.

Vậy thôi. Đây là một ví dụ không có kiểm tra lỗi:

``` {.c}
mqd_t mqdes = mq_open("/waco_kid", O_RDONLY | O_CREAT, 0644, NULL);

mq_send(mqdes, "Play chess", 10, 0);
```

Nếu bạn gửi khi hàng đợi đầy, lệnh gọi sẽ block cho đến khi có gì đó
xóa một tin nhắn khỏi hàng đợi để nhường chỗ.

### Nhận Thứ Gì Đó Từ Hàng Đợi

Chiều ngược lại là nhận. Về cơ bản giống nhau.

``` {.c}
#include <mqueue.h>

ssize_t mq_receive(mqd_t mqdes, char msg_ptr[msg_len],
                   size_t msg_len, unsigned int *msg_prio);
```

Lệnh đó sẽ nhận một tin nhắn từ hàng đợi được xác định bởi `mqdes`. Nó
lưu tin nhắn vào `msg_ptr`, cái này phải là một buffer ít nhất `msg_len`
byte, nếu không thì có chuyện đấy. Ồ, và `msg_len` cũng phải ít nhất
bằng kích thước tin nhắn tối đa (mà bạn tùy chọn đặt với `mq_open()`),
không thì cũng có chuyện.

Cuối cùng, nếu bạn quan tâm đến ưu tiên của tin nhắn này, bạn có thể
truyền con trỏ tới một `unsigned int` trong `msg_prio` để giữ nó. Hoặc
bạn có thể truyền `NULL` cho đối số đó nếu không quan tâm.

``` {.c}
mqd_t mqdes = mq_open("/waco_kid", O_RDONLY);

char msg[8192];
ssize_t recv_len;
unsigned int msg_prio;

recv_len = mq_receive(mqdes, msg, sizeof msg, &msg_prio);

// Print it to stdout
write(1, msg, recv_len);
```

Nhắc lại, bạn nên kiểm tra lỗi cho những lệnh đó.

### Đóng Hàng Đợi

Khi bạn dùng xong hàng đợi *trong một tiến trình cụ thể*, bạn có thể
đóng nó lại. (Hàng đợi sẽ tiếp tục tồn tại cho đến khi bị unlink.)

``` {.c}
#include <mqueue.h>

int mq_close(mqd_t mqdes);
```

Khá đơn giản. Đây là một ví dụ cho đầy đủ:

``` {.c}
mqd_t mqdes = mq_open("/waco_kid", O_RDONLY);

// ...
// Làm việc với hàng đợi một lúc rồi xong.
// ...

mq_close(mqdes);
```

## Ví Dụ Sender

Hãy làm một ví dụ hoàn chỉnh. Đoạn code này sẽ nhắc bạn nhập ưu tiên
và tin nhắn cách nhau bằng dấu cách, kiểu như `5 Hello`. Nhập dòng
trắng để thoát.

Và nó sẽ gửi chuỗi kết thúc null ra hàng đợi.

``` {.c}
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <mqueue.h>

/**
 * Input a priority and message from the keyboard.
 *
 * Really fragile--for demo purposes only.
 */
int input(char *buf, size_t bufsize, unsigned int *msg_prio)
{
    printf("Priority and message (e.g. 2 hi): ");
    fflush(stdout);
    fgets(buf, bufsize - 1, stdin);
    buf[bufsize - 1] = '\0';

    char *token = strtok(buf, " \n");

    if (token == NULL)
        return 0;
    
    *msg_prio = atoi(token);  // Get priority

    token = strtok(NULL, "\n");
    int msg_len = strlen(token) + 1;

    memmove(buf, token, msg_len);

    return msg_len;
}

int main(void)
{
    char msg[128];

    struct mq_attr attr = {
        .mq_maxmsg = 3,
        .mq_msgsize = 256
    };

    mqd_t mqdes = mq_open("/mq_test", O_WRONLY | O_CREAT, 0644,
                          &attr);

    for (;;) {
        unsigned int msg_prio;

        int msg_len = input(msg, sizeof msg, &msg_prio);

        if (msg_len == 0)
            break;

        printf("sending \"%s\" (%d bytes) at priority %u\n", msg,
               msg_len, msg_prio);

        if (mq_send(mqdes, msg, msg_len, msg_prio) == -1) {
            perror("mq_send");
        }
    }

    mq_close(mqdes);
}
```

Chạy chương trình đó và gửi một vài thứ. Lưu ý rằng số lượng tin nhắn
tối đa trong hàng đợi tại một thời điểm được đặt là `3`, vì vậy khi bạn
cố gửi thứ thứ tư, nó sẽ block cho đến khi bạn khởi động một receiver.

``` {.default}
$ ./mq_sender
  Priority and message (e.g. 2 hi): 1 hello
  sending "hello" (6 bytes) at priority 1
  Priority and message (e.g. 2 hi): 2 and this
  sending "and this" (9 bytes) at priority 2
  Priority and message (e.g. 2 hi): 0 low priority
  sending "low priority" (13 bytes) at priority 0
  Priority and message (e.g. 2 hi): 2 a fourth message
  sending "a fourth message" (17 bytes) at priority 2
```

Và ở đó tôi đã bị block. Cứ để nó ngồi đó, và hãy khởi động một
receiver trong terminal khác.

## Ví Dụ Receiver

Đây là một receiver nhận tin nhắn.

``` {.c}
#include <fcntl.h>
#include <sys/stat.h>
#include <mqueue.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>

int main(void)
{
    mqd_t mqdes = mq_open("/mq_test", O_RDONLY);

    char msg[128];
    char msg_len = sizeof msg;
    unsigned int msg_prio;
    ssize_t bytes_received;

    for (;;) {
        bytes_received = mq_receive(mqdes, msg, msg_len,
                                    &msg_prio);

        if (bytes_received == -1) {
            perror("mq_receive");
            return 1;
        }

        printf("received \"%s\" (%zd bytes) at priority %u\n", msg,
               bytes_received, msg_prio);
    }

    mq_close(mqdes);
}
```

Giả sử bạn vẫn đang chạy sender ở trên trong một cửa sổ, và bạn vừa
khởi động cái này trong cửa sổ khác, bạn sẽ thấy ngay hai điều.

Một là receiver sẽ ngốm hết và in ra tất cả các tin nhắn trong hàng
đợi. Điều kia là sender sẽ ngay lập tức được unblock và cho bạn cơ hội
gõ thêm tin nhắn khác.

Receiver sẽ in ra:

``` {.default}
$ ./mq_receiver
  received "and this" (9 bytes) at priority 2
  received "a fourth message" (17 bytes) at priority 2
  received "hello" (6 bytes) at priority 1
  received "low priority" (13 bytes) at priority 0
```

Chú ý thứ tự! Tin nhắn thứ tư ta gửi thực ra đến thứ hai. Tại sao? Vì
nó có ưu tiên 2, nên nó được nhận trước bất cứ thứ gì có ưu tiên thấp
hơn, dù những tin nhắn ưu tiên thấp hơn đó được gửi trước. Kẻ chen
hàng!

Và lúc này, nếu bạn gõ gì đó ở sender, chúng sẽ ngay lập tức xuất hiện
trên receiver.

## Nhiều Tiến Trình

Nếu bạn có nhiều sender, chúng sẽ đổ tin nhắn vào cùng một hàng đợi
theo cách trực quan. Không vấn đề gì.

Nếu bạn có nhiều receiver, tôi thực ra không chắc đặc tả nói gì về
điều đó. Nhưng khi tôi chạy trên Linux, có vẻ như các receiver thay
nhau nhận tin nhắn.

Và đây là hành vi hợp lý. Có lẽ bạn có một tiến trình tạo ra các công
việc và đưa chúng vào hàng đợi, và bạn có nhiều tiến trình chạy các
công việc đó, tất cả đều với tay vào hàng đợi để lấy việc tiếp theo cần
làm.

Hãy thử! Mở thêm một cửa sổ nữa, khởi động receiver thứ hai, và xem
các tin nhắn từ sender đi đâu.

## Unlink (Xóa) Hàng Đợi

Nếu tất cả các chương trình `mq_close()` hàng đợi, nó có biến mất
không? ***Không***, nó không biến mất. Nó vẫn còn đó. Và nếu có tin
nhắn trong đó, chúng cũng còn đó.

Bạn phải _unlink_ hàng đợi, điều này hơi tương tự như xóa một file.

``` {.c}
#include <mqueue.h>

int mq_unlink(const char *name);
```

Bạn chỉ cần truyền tên mà bạn đã tạo hàng đợi:

``` {.c}
mq_unlink("/waco_kid");
```

Và vậy là xong.

Cũng gần như vậy. Có một vài chi tiết phức tạp. Nếu bạn unlink hàng
đợi, nó thực sự tiếp tục tồn tại cho đến khi tất cả người dùng của hàng
đợi đã thoát hoặc `mq_close()` nó.

Vậy nếu *mọi người* đã đóng nó **và** bạn unlink nó, thì nó biến mất.

Ngoài ra, nếu bạn unlink nó nhưng vẫn giữ nó mở, một tiến trình khác
có thể tạo một hàng đợi khác cùng tên mà bạn đã dùng.

> Đây thực ra chính xác là cách xóa file (sử dụng syscall `unlink()`)
> hoạt động. Bạn có thể unlink một file và giữ nó mở; file thực sự không
> bị xóa khỏi đĩa cho đến khi nó được unlink **và** tất cả các tiến
> trình đã đóng nó.

Đây là một ví dụ unlink hàng đợi tin nhắn từ các ví dụ trước. Nếu bạn
không chạy cái này, hàng đợi sẽ tồn tại cho đến khi bạn khởi động lại
máy.

``` {.c}
#include <stdio.h>
#include <mqueue.h>

int main(void)
{
    if (mq_unlink("/mq_test") == -1) {
        perror("/mq_test");
        return 1;
    }
}
```

## Siêu Dữ Liệu Hàng Đợi

Bạn có thể xem các thuộc tính của hàng đợi, một vài trong số đó bạn có
thể đã đặt trong lệnh `mq_open()`.

Các lệnh gọi này dùng người bạn cũ `struct mq_attr` để giữ thông tin.

``` {.c}
struct mq_attr {
    long mq_flags;     // O_NONBLOCK?
    long mq_maxmsg;    // Max message count
    long mq_msgsize;   // Max message size
    long mq_curmsgs;   // How many messages in queue
};
```

Bạn có thể biết hàng đợi được tạo là non-blocking hay không bằng cách
nhìn vào `mq_flags`. Nếu bạn AND theo bit với `O_NONBLOCK` và kết quả
khác không, thì nó là non-blocking. Không, không, không.

Và, rõ ràng, bạn có thể biết hàng đợi đầy đến mức nào bằng cách nhìn
vào `mq_curmsgs`.

Bạn cũng có thể đặt các thuộc tính, nhưng thứ duy nhất bạn được phép
đặt là `mq_flags`. Vì vậy đây là cách bạn có thể chuyển một hàng đợi
từ blocking sang non-blocking hoặc ngược lại. Tất cả các trường khác bị
bỏ qua khi đặt thuộc tính.

Đây là getter và setter:

``` {.c}
#include <mqueue.h>

int mq_getattr(mqd_t mqdes, struct mq_attr *attr);

int mq_setattr(mqd_t mqdes, const struct mq_attr *newattr,
               struct mq_attr *oldattr);
```

Setter cũng trả về cho bạn các thuộc tính trước đó trong `oldattr`, nếu
nó không phải `NULL`.

Đây là một ví dụ xem có bao nhiêu tin nhắn trong hàng đợi rồi chuyển nó
sang non-blocking.

``` {.c}
struct mq_attr attr;

mq_getattr(mqdes, &attr);

printf("Currently in queue: %ld\n", attr.mq_curmsgs);

attr.mq_flags |= O_NONBLOCK;
mq_setattr(mqdes, &attr, NULL);
```

## Hết Giờ!

Tôi sẽ không đi vào quá nhiều chi tiết ở đây, nhưng với những lệnh gọi
block này, đôi khi ta muốn chỉ chờ một khoảng thời gian nhất định trước
khi bỏ cuộc.

Bạn có thể dùng các lệnh gọi `mq_timedsend()` và `my_timedreceive()` hoạt
động giống như `mq_send()` và `mq_receive()` ngoại trừ chúng có thêm
`struct timespec` ở cuối cho phép bạn chỉ định thời gian chờ tối đa.

Nếu hết thời gian, lệnh gọi trả về `-1` và `errno` được đặt thành
`ETIMEDOUT`.

Để nhắc nhanh, `struct timespec` có hai trường:

* `tv_sec` số giây, cộng thêm...
* `tv_nsec` số nanosecond

Có 1.000.000.000 (một tỷ) nanosecond trong một giây, vì vậy trường
`tv_nsec` nằm trong khoảng từ `0` đến `999999999`.

Đây là một `struct timespec` cho bạn thời gian chờ 3,75 giây:

``` {.c}
struct timespec timelimit = {
    .tv_sec = 3,
    .tv_nsec = 750000000
}
```

## Blocking và Non-Blocking

Nói chung, nếu bạn cố gửi một tin nhắn vào hàng đợi đầy, lệnh gọi
`mq_send()` sẽ block.

Và nếu bạn cố nhận từ một hàng đợi trống bằng `mq_receive()`, lệnh gọi
sẽ block.

Nếu điều đó không mong muốn, bạn có thể đặt hàng đợi sang non-blocking.
Bạn làm điều này bằng cách truyền flag `O_NONBLOCK` vào `mq_open()`, hoặc
bằng cách đặt nó sau đó bằng `mq_setattr()`.

Nếu bạn đặt hàng đợi là non-blocking, tất cả những lệnh gọi *sẽ* block
trong trường hợp bình thường sẽ trả về `-1` và `errno` sẽ được đặt thành
`EWOULDBLOCK`.
