<!-- Beej's guide to IPC

# vim: ts=4:sw=4:nosi:et:tw=72
-->

<!-- ======================================================= -->
<!-- Signals Part 2 -->
<!-- ======================================================= -->

# Signals Phần II

Trong phần này của hướng dẫn, chúng ta sẽ xem xét cách chặn signal, và
một số thực hành tốt nhất để viết các hàm signal handler mà không gặp
rắc rối nghiêm trọng. Nhưng trước tiên, hãy đi vào một số chi tiết tinh
tế.

## Các Trường Hợp Biên

Hãy nói về những thứ kỳ lạ.

Điều gì xảy ra nếu signal handler của bạn đang chạy và một signal khác
đến? Một cách hợp lý, theo mặc định, signal thứ hai sẽ bị hoãn lại cho
đến khi signal handler kết thúc[^a399].

[^a399]: Bạn có thể ghi đè điều này với `SA_NODEFER` trong `sa_flags`,
    nhưng đó chắc chắn là con đường dẫn đến điên loạn.

OK vậy thì... Điều gì xảy ra nếu đã có một signal bị hoãn và một signal
khác đến? Trong trường hợp đó, hai signal bị gộp thành một và chỉ có một
cái đến! Nếu bạn nhận được một signal, bạn có thể chắc chắn rằng nó đã
được phát một hoặc nhiều lần trước khi handler của bạn thấy nó.

Vì vậy đừng mong đợi một *số lần đếm*. Khi handler của bạn được gọi, tất
cả những gì bạn có thể chắc chắn là signal đã được phát ít nhất một lần.

Bây giờ trở lại những thứ thú vị.

## Chặn Signal

Bạn có thể chặn signal không đến. Điều này không loại bỏ signal; nó chỉ
giữ chúng lại một lúc. Nếu bạn đang chặn một signal và nó đến, sẽ không
có gì xảy ra... cho đến khi bạn bỏ chặn và nó sẽ đến ngay lập tức.

Bạn làm điều này với lệnh gọi `sigprocmask()`[^e0e0]. Hàm này thao tác
bảng signal bị chặn của từng tiến trình.

[^e0e0]: Nếu bạn đang dùng POSIX thread, hãy dùng tương đương
    `pthread_sigmask()` thay thế, để thực hiện điều này trên cơ sở
    từng thread.

Đây là nguyên mẫu:

``` {.c}
#include <signal.h>

int sigprocmask(int how, const sigset_t *restrict set,
                sigset_t *restrict oset);
```

Hơi lộn xộn, nhưng `how` đang nói "chặn hay bỏ chặn". Và `set` là tập
hợp các signal cần chặn. Cuối cùng, `oset` là tập hợp *trước đó* của
các signal bị chặn để bạn có thể chuyển lại sau. Bạn có thể đặt `oset`
thành `NULL` nếu bạn không quan tâm đến tập hợp trước đó.

Trường `how` có thể được đặt thành ba thứ tuyệt vời:

|`how`|Mô tả|
|-----|----------------------------------------------------|
|`SIG_BLOCK`|Thêm signal vào danh sách signal đang bị chặn hiện tại.|
|`SIG_UNBLOCK`|Loại bỏ signal khỏi danh sách signal đang bị chặn hiện tại.|
|`SIG_SETMASK`|Đặt danh sách signal đang bị chặn hiện tại chính xác thành danh sách này.|

Vậy hãy thử trong demo này, [flx[`sigblock.c`|sigblock.c]]:

``` {.c .numberLines}
#include <stdio.h>
#include <unistd.h>
#include <signal.h>

int main(void)
{
    sigset_t mask, oldmask;

    // Make a set with SIGINT in it
    sigemptyset(&mask);
    sigaddset(&mask, SIGINT);

    // Block everything in that set
    sigprocmask(SIG_BLOCK, &mask, &oldmask);

    // SIGINT is blocked for now!
    puts("Try to ^C out of here! You can't for 5 seconds!");
    sleep(5);

    // Back to how it was before, presumably without blocking SIGINT
    puts("Ok, now you can.");
    sigprocmask(SIG_SETMASK, &oldmask, NULL);

    puts("If you hit ^C, this won't print.");
}
```

Nếu bạn nhấn `CTRL-C` trong khi `sleep()`, bạn sẽ thấy chương trình
không bị ngắt. Bạn đang tạo ra `SIGINT`, nhưng chúng bị chặn. Và chúng
sẽ được gửi ngay khi bị bỏ chặn, điều xảy ra với `sigprocmask(SIG_SETMASK...`
ở dòng 22.

Và vì chúng bị bỏ chặn và chúng ta đang dùng default handler (thoát),
tiến trình sẽ thoát ngay sau khi chúng ta bỏ chặn chúng, **trước** khi
`puts()` cuối cùng.

## Thực hành Hàm Signal Handler

Vì các hàm signal handler bị hạn chế như vậy, pattern chung mà các lập
trình viên thích là để signal handler thực sự không làm gì ngoài việc
thông báo cho code chính rằng điều gì đó đã xảy ra, và chỉ vậy thôi.

Hãy xem một biến thể của ví dụ trước. Lưu ý đây **không** phải là cách
bạn nên code điều này.

``` {.c}
volatile sig_atomic_t signal_happened;

void handler(int sig)
{
    signal_happened = 1;
}

int main(void)
{
    // ... signal setup ...

    while (!signal_happened) { /* spin */ }

    puts("Signal happened!");
    signal_happened = 0;

    // ... etc. ...
}
```

Bạn không muốn làm điều này vì nó chỉ quay vòng ngốn CPU như thể không
có ngày mai trong khi chờ signal. Nhưng đó là một ví dụ cơ bản về
pattern chung. Chúng ta chỉ cần loại bỏ spin-wait.

Điều này có nghĩa là chúng ta sẽ cho tiến trình chính ngủ theo cách nào
đó, ví dụ:

``` {.c}
while (!signal_happened) { sleep(1000000); }
```

Tốt hơn rồi! Giả sử bạn không chỉ định `SA_RESTART`, `sleep()` sẽ thất
bại với `EINTR` ngay khi signal được phát và bạn sẽ thoát khỏi vòng lặp.
Đúng là nó thức dậy để kiểm tra mỗi mười một ngày rưỡi, và điều đó dùng
một chút CPU, nhưng đó là điều tôi có thể chấp nhận.

Và, như chúng ta đã thấy trước đó, điều tuyệt vời ở đây là signal
handler đã không làm gì ngoài việc thực hiện một ghi atomic vào một
biến global. Mọi thứ khác được xử lý gọn gàng bởi chương trình, vì vậy
chúng ta không phải lo lắng về các ghi không-atomic hoặc race condition.

Nhưng chương trình đó thật *nhàm chán*! Nó không làm gì cả!

Nếu chúng ta muốn ứng dụng làm việc **và** xử lý signal thì sao? Ôi
thôi, đừng phát điên.

Đoán xem! Chúng ta có các lựa chọn. Tôi sẽ đưa ra hai ở đây, và bạn
thực sự có thể dùng bất kỳ cái nào phù hợp. Cả hai đều giả định bạn
đang sử dụng thứ gì đó như `select()` hoặc `poll()` để xử lý các sự
kiện I/O bất đồng bộ và đó là thứ điều khiển chương trình của bạn. Hoặc
ít nhất, chúng giả định rằng bạn có thể điều chỉnh code để làm điều đó.

Và nếu bạn cần ôn lại, hãy xem [fl[_Hướng dẫn Lập trình Mạng của
Beej_|https://beej.us/guide/bgnet/]], đặc biệt là các phần về
[fl[`poll()`|https://beej.us/guide/bgnet/html/split/slightly-advanced-techniques.html#poll]]
và
[fl[`select()`|https://beej.us/guide/bgnet/html/split/slightly-advanced-techniques.html#select]].

### Sử dụng Pipe

Nếu bạn đã sử dụng `select()` hoặc `poll()` để chờ đợi các sự kiện,
cách tiếp cận này có thể hoạt động cho bạn khá tiện.

Ý tưởng là bạn sẽ tạo một pipe. Tiến trình chính thêm đầu đọc của pipe
vào tập hợp file descriptor mà `select()` hoặc `poll()` của nó đang chờ.

Sau đó, khi một signal đến, signal handler ghi một định danh đơn giản
vào pipe. Sau đó tiến trình chính sẽ trở về từ `select()` hoặc `poll()`
và bạn có thể xem những gì trong pipe. Định danh cho bạn biết signal nào
đã được xử lý.

Đây là một đoạn từ chương trình demo [flx[`pipesig.c`|pipesig.c]]. Nó
chờ nhập văn bản từ `stdin` cũng như chờ thông tin đến trên pipe. (Trong
trường hợp này, chúng ta sẽ dùng `poll()`, nhưng `select()` cũng hoạt
động tốt như nhau.) Nó khởi động một tiến trình nền phát `SIGUSR1` trên
tiến trình cha mỗi vài giây.

``` {.c}
int pipefd[2];

void handler(int sig)
{
    (void)sig;
    write(pipefd[1], "1", 1);
}
```

Đó là tất cả cho signal handler! Nó chỉ đưa một ký tự ASCII `1` vào
pipe. Hết.

Hãy xem cách nó được xử lý (code đã được đơn giản hóa ở đây trong văn
bản---xem nguồn đầy đủ để thấy cách nó hoạt động):

``` {.c}
struct pollfd pollfds[2] = {
    { .fd=0, .events=POLLIN },
    { .fd=pipefd[0], .events=POLLIN },
};

st = poll(pollfds, 2, 0);

// ...

if ((pollfds[0].revents & POLLIN)) {
    if (fgets(line, sizeof line, stdin) == NULL) return;

    int len = strlen(line);
    if (line[len-1] == '\n') line[len-1] = '\0';

    if (strcmp(line, "quit") == 0) return;

    printf("You entered: \"%s\"\n", line);
}

else if ((pollfds[1].revents & POLLIN)) {
    char sigdata[1024];

    int count = read(pipefd[0], sigdata, sizeof sigdata);

    for (int i = 0; i < count; i++)
        if (sigdata[i] == '1')
            printf("SIGUSR1 occurred\n");
}
```

Ở đó chúng ta thiết lập mảng `pollfds` để theo dõi file descriptor `0`
(standard input có thể từ bàn phím) và file descriptor `pipefd[0]`, đầu
đọc của pipe.

Nếu chúng ta nhận được gì đó từ `stdin`, chúng ta xử lý nó bằng cách
in ra. Nếu chúng ta nhận được gì đó trên pipe, chúng ta kiểm tra định
danh và in ra điều gì đã xảy ra. (Rõ ràng tôi có một số vấn đề ở đây
nếu có hơn 1024 signal xảy ra trước khi tôi thức dậy để xử lý `poll()`,
nhưng việc sửa điều đó được để lại như một bài tập cho bạn và môi trường
tính toán hiệu năng cao của bạn.)

Đây là một số đầu ra từ một lần chạy mẫu:

``` {.default}
Enter lines of text, or "quit" to quit.
hi
You entered: "hi"
SIGUSR1 occurred
This is a long lSIGUSR1 occurred
ine of text
You entered: "This is a long line of text"
SIGUSR1 occurred
quit
Quitting, sending SIGTERM to child
```

Khá đơn giản. Đúng, signal handler đang gọi `write()` và dùng một pipe
descriptor global không phải atomic, nhưng chúng ta chỉ đặt pipe
descriptor ở đầu lần chạy trước khi signal handler được cài đặt. Và
chúng ta không sửa đổi nó sau đó. Vì vậy sự an toàn tương đối được đảm
bảo.

### Sử dụng `pselect()`

Nếu bạn đã dùng `select()`, đây có thể là cách sạch hơn so với pipe để
thông báo cho tiến trình rằng một signal đã xảy ra.

Một hacker Unix thông minh đã nghĩ theo cách này: nếu có một phiên bản
của `select()` có thể thức dậy khi một trong số các signal cụ thể được
phát? Và nó có thể làm điều này ngoài tất cả việc giám sát file
descriptor mà nó thường làm?

Và vì vậy họ đã tạo ra điều đó.

``` {.c}
#include <sys/select.h>

int pselect(int nfds,
            fd_set *restrict readfds,
            fd_set *restrict writefds,
            fd_set *restrict errorfds,
            const struct timespec *restrict timeout,
            const sigset_t *restrict sigmask);
```

Trông giống `select()` phải không? Sự khác biệt duy nhất là:

* Timeout là `struct timespec` thay vì `struct timeval`.
* Chúng ta có `sigmask` như tham số cuối.

Trong demo, chúng ta sẽ để `timeout` là `NULL` nên nó không bao giờ hết
thời gian, nhưng bạn hoàn toàn có thể thêm vào nếu muốn.

Và `sigmask` nên giữ một tập hợp các signal cần bị chặn trong khi gọi
`pselect()`... cái mà **không** nên bao gồm signal bạn đang xử lý!

Nghe có vẻ vô nghĩa. Hãy xem cách tiếp cận tổng thể mà tiến trình chính
sẽ thực hiện:

1. Thiết lập signal handler, giả sử cho `SIGUSR1`.
2. Chặn `SIGUSR1` với `sigprocmask()`.
3. Gọi `pselect()` với `sigmask` **không** bao gồm `SIGUSR1`.
4. Khi `pselect()` trả về, kiểm tra xem có phải do signal không.

Vậy nếu `SIGUSR1` bị chặn, làm sao nó lọt qua được? Đây là phần ma
thuật.

`pselect()` lấy `sigmask` bạn truyền vào và đặt signal mask của tiến
trình thành nó. Giả sử bạn truyền một tập hợp rỗng. Trong trường hợp đó,
không có signal nào bị chặn, và tất cả chúng sẽ lọt qua. Vì vậy trong
khi bạn đang gọi `pselect()`, `SIGUSR1` không bị chặn và nó có thể hoạt
động.

Và rồi (cho phần ma thuật kia), sau khi signal đến, `pselect()` *khôi
phục* signal mask của tiến trình về trạng thái trước đó.

Kết quả thực tế của tất cả điều này là tiến trình của bạn đã chặn
`SIGUSR1` ở mọi nơi *ngoại trừ* trong khi `pselect()` đang được gọi!
Điều này cho bạn quyền kiểm soát trung tâm về thời điểm xử lý signal và
phải làm gì.

Pseudocode cho `pselect()` trông gần như thế này:

``` {.python}
pselect(readset, timeout, sigmask):
    sigprocmask(SIG_SETMASK, sigmask, oldmask);
    select(readset, timeout)
    sigprocmask(SIG_SETMASK, oldmask, NULL);
```

Tính năng chính là, vì đây là một syscall, tất cả điều này xảy ra
nguyên tử từ góc nhìn của chúng ta. Chúng ta không thể viết điều này
trong user space mà không bị racy.

Hãy xem ví dụ [flx[`pselect.c`|pselect.c]], giống như ví dụ `poll()` ở
trên, ngoại trừ nó dùng `pselect()`. Đây là handler.

``` {.c}
volatile sig_atomic_t sigusr1_happened;

void handler(int sig)
{
    sigusr1_happened = 1;
}
```

Một lần nữa, ngắn gọn. Chúng ta chỉ đặt một cờ atomic global cho biết
signal đã xảy ra. Hãy xem phần code chính (một lần nữa, đã chỉnh sửa
cho ngắn gọn):

``` {.c}
sigset_t mask, oldmask;
sigemptyset(&mask);
sigaddset(&mask, SIGUSR1);
sigprocmask(SIG_BLOCK, &mask, &oldmask);

// ...

FD_ZERO(&readfds);
FD_SET(0, &readfds);
st = pselect(1, &readfds, NULL, NULL, NULL, &oldmask);

if (st == -1 && errno == EINTR) {
    if (sigusr1_happened) {
        sigusr1_happened = 0;
        printf("SIGUSR1 occurred\n");
    }

} else if (st > 0 && FD_ISSET(0, &readfds)) {
    if (fgets(line, sizeof line, stdin) == NULL)
        return;

    int len = strlen(line);
    if (line[len-1] == '\n') line[len-1] = '\0';

    if (strcmp(line, "quit") == 0)
        return;

    printf("You entered: \"%s\"\n", line);
}
```

Một vài điều cần giải thích ở đây.

* Chúng ta tạo một `mask` mới với `SIGUSR1` trong đó và chặn signal đó.
* Chúng ta giữ mask cũ (trong trường hợp này là tập hợp rỗng), và chúng
  ta sẽ dùng nó làm tập hợp để chặn với `pselect()`.
* Chúng ta thêm file descriptor `0` (`stdin`) vào `readfds` để
  `pselect()` sẽ trả về nếu chúng ta gõ gì đó.
* Chúng ta gọi `pselect()`.
* Nếu nó trả về `-1` và `errno` là `EINTR`, nghĩa là `pselect()` bị
  ngắt bởi một signal! Chúng ta sau đó kiểm tra global của mình để xem
  có phải là signal của chúng ta không.
* Nếu nó trả về dương (`0` nghĩa là hết thời gian), phải là một trong
  các file descriptor của chúng ta. Chúng ta kiểm tra xem có phải file
  descriptor `0` (`stdin`) không, và nếu vậy, chúng ta đọc dữ liệu với
  `fgets()`.

Vì vậy, một lần nữa, chúng ta có phần xử lý signal ở vòng lặp chính nơi
nó nằm trong tầm kiểm soát của chúng ta và chúng ta không phải đối phó
với các vấn đề đồng thời khó chịu.

Phần `oldmask` đó khá kỳ lạ. Bằng cách làm như vậy, về cơ bản chúng ta
đang nói với `pselect()` rằng chúng ta chỉ muốn được thông báo khi
`SIGUSR1` đến và không phải signal nào khác. Chúng ta chặn tất cả những
gì đã bị chặn trước khi chúng ta thêm `SIGUSR1` vào tập hợp. (Trong
trường hợp này, không có signal nào khác, vì vậy `oldmask` là tập hợp
rỗng.)

## Kết luận

Vậy là đó. Một số kỹ thuật lạ lùng mà chúng ta có để thực sự xử lý đúng
các POSIX signal. Những điểm chính là bạn có thể xử lý tất cả các loại
signal và bạn có thể chặn việc gửi chúng. Ngoài ra bạn chỉ nên sửa đổi
các biến global trong signal handler nếu chúng là atomic. Và nếu các
biến global được ghi vào ở bất kỳ đâu trong khi handler đang hoạt động,
chúng cũng nên là atomic.

Và nếu bạn muốn xử lý signal đúng cách, thực sự nên xử lý ở vòng lặp
chính trừ khi bạn chỉ bỏ qua chúng. Và bạn có thể dùng pipe hoặc
`pselect()` để hỗ trợ điều này.

Lập trình an toàn, và chú ý những con rồng!
