<!-- Beej's guide to IPC

# vim: ts=4:sw=4:nosi:et:tw=72
-->

<!-- ======================================================= -->
<!-- Signals -->
<!-- ======================================================= -->

# Signals (Tín hiệu)

Có một phương pháp đôi khi rất hữu ích để một tiến trình "quấy rầy" tiến
trình khác: signal. Về cơ bản, một tiến trình có thể "raise" (phát) một
signal và gửi nó đến một tiến trình khác. Signal handler (chỉ là một hàm)
của tiến trình đích sẽ được gọi và tiến trình có thể xử lý nó.

Đây là một cơ chế thú vị khác với những gì bạn có thể quen: chương trình
của bạn đang chạy vui vẻ làm công việc của nó, và rồi một signal được
phát và chương trình của bạn bị ngắt. Code của bạn có thể đang ở giữa
một hàm tính π đến 1,21 tỷ chữ số thập phân, và đột nhiên nó dừng lại
và quyền điều khiển chuyển sang một hàm khác bạn đã viết (là _signal
handler_) để xử lý signal.

Và khi signal handler trả về, quyền điều khiển nhảy lại vào phép tính π
của bạn và tiếp tục từ chỗ đã dừng. Hoặc có thể chương trình chỉ đơn
giản là kết thúc! Tất cả phụ thuộc vào signal và việc bạn có quyết định
xử lý nó hay không và xử lý như thế nào.

Tất nhiên, ma quỷ ở trong các chi tiết, và trên thực tế những gì bạn
được phép thực hiện an toàn bên trong signal handler của mình khá hạn
chế. Dẫu vậy, signal vẫn cung cấp một dịch vụ hữu ích.

Ví dụ, một tiến trình có thể muốn tạm thời dừng một tiến trình khác, và
điều này có thể được thực hiện bằng cách gửi signal `SIGSTOP` đến tiến
trình đó. Để tiếp tục, tiến trình phải nhận signal `SIGCONT`[^847f]. Làm
sao tiến trình biết phải làm điều này khi nhận được một signal nhất định?
Thực ra nhiều signal được định nghĩa sẵn và tiến trình có một default
signal handler để xử lý chúng.

[^847f]: Mẹo vui: khi bạn nhấn `CTRL-Z` trong terminal trong khi đang
    chạy một chương trình ở foreground, nó sẽ gửi `SIGSTOP` đến tiến
    trình đó và shell báo cáo rằng nó đã bị dừng hoặc tạm dừng. Nếu
    bạn gõ `fg`, nó sẽ đưa tiến trình đó trở lại foreground và gửi
    `SIGCONT` để tiếp tục chạy từ chỗ đã dừng.

Default handler? Đúng vậy. Lấy `SIGINT` làm ví dụ. Đây là signal ngắt
mà một tiến trình nhận được khi người dùng nhấn `CTRL-C`. Default signal
handler cho `SIGINT` khiến tiến trình thoát! Nghe quen không? Thực ra,
như bạn có thể tưởng tượng, bạn có thể ghi đè signal `SIGINT` để làm bất
cứ điều gì bạn muốn (hoặc không làm gì cả!) Bạn có thể khiến tiến trình
in ra "Interrupt?! No way, Jose!" và tiếp tục công việc vui vẻ của nó.

Vậy giờ bạn biết rằng bạn có thể khiến tiến trình của mình phản ứng với
hầu hết mọi signal theo bất kỳ cách nào bạn muốn. Tất nhiên, có những
ngoại lệ vì nếu không thì sẽ quá dễ để hiểu. Hãy xem `SIGKILL` nổi
tiếng, signal số 9. Bạn đã từng gõ "`kill -9 nnnn`" để tắt một tiến
trình số `nnnn` đang chạy loạn không? Bạn đã gửi cho nó `SIGKILL`. Bạn
cũng có thể nhớ rằng không tiến trình nào có thể thoát khỏi "`kill -9`",
và điều đó hoàn toàn đúng. `SIGKILL` là một trong những signal bạn
**không thể** thêm signal handler riêng. `SIGSTOP` đã đề cập ở trên
cũng thuộc danh mục này.

(Ghi chú thêm: bạn thường dùng lệnh Unix `kill` mà không chỉ định signal
cần gửi...vậy signal đó là gì? Câu trả lời: `SIGTERM`. Bạn có thể viết
handler riêng cho `SIGTERM` để tiến trình của bạn không phản ứng với lệnh
"`kill`" thông thường, và người dùng phải dùng "`kill -9`" để kết thúc
tiến trình.)

Tất cả signal đều được định nghĩa sẵn không? Sẽ ra sao nếu bạn muốn gửi
một signal có ý nghĩa chỉ bạn hiểu đến một tiến trình? Có hai signal
không được đặt trước: `SIGUSR1` và `SIGUSR2`. Bạn hoàn toàn tự do dùng
chúng cho bất cứ điều gì và xử lý chúng theo bất kỳ cách nào bạn chọn.
(Ví dụ, chương trình CD player của tôi có thể phản ứng với `SIGUSR1` bằng
cách chuyển sang bài hát tiếp theo. Bằng cách đó, tôi có thể điều khiển
nó từ dòng lệnh bằng cách gõ "`kill -SIGUSR1 nnnn`".)

## Bắt Signal để Vui và Kiếm Lợi!

Như bạn có thể đoán, lệnh Unix "kill" là một cách để gửi signal đến một
tiến trình. Thật trùng hợp không thể tin được, có một system call gọi là
`kill()` làm điều tương tự. Nó nhận một số signal (như được định nghĩa
trong `signal.h`) và một process ID làm đối số. Ngoài ra, còn có một thư
viện routine gọi là `raise()` có thể dùng để phát một signal trong chính
tiến trình đó.

Câu hỏi nóng bỏng vẫn còn đó: làm thế nào để bạn bắt một `SIGTERM` đang
bay? Bạn cần gọi `sigaction()` và cho nó biết tất cả các chi tiết về
signal bạn muốn bắt và hàm bạn muốn gọi để xử lý nó.

Đây là phân tích `sigaction()`:

``` {.c}
int sigaction(int sig, const struct sigaction *act,
              struct sigaction *oact);
```

Tham số đầu tiên, `sig` là signal cần bắt. Đây có thể là (có lẽ "nên"
là) một tên ký hiệu từ `signal.h` kiểu như `SIGINT`. Đó là phần dễ.

Trường tiếp theo, `act` là con trỏ đến một `struct sigaction` có nhiều
trường bạn có thể điền vào để kiểm soát hành vi của signal handler. (Con
trỏ đến chính hàm signal handler được bao gồm trong `struct`.)

Cuối cùng `oact` có thể là `NULL`, nhưng nếu không, nó trả về thông tin
signal handler _cũ_ đã có trước đó. Điều này hữu ích nếu bạn muốn khôi
phục signal handler trước đó vào một lúc nào đó sau.

Chúng ta sẽ tập trung vào ba trường này trong `struct sigaction`:

|Signal|Mô tả|
|------------|----------------------------------------------------------|
|`sa_handler`|Hàm signal handler|
|`sa_mask`|Tập hợp các signal cần chặn trong khi signal này đang được xử lý|
|`sa_flags`|Các cờ để thay đổi hành vi của handler, hoặc `0`|

`sa_handler` là con trỏ đến một hàm trả về `void` và nhận một tham số
`int` duy nhất (sẽ giữ số signal mà nó đang xử lý). Bạn cũng có thể chỉ
định `SIG_IGN` để bỏ qua signal, hoặc `SIG_DEF` để đặt nó về hành động
mặc định.

Còn trường `sa_mask`? Khi bạn đang xử lý một signal, bạn có thể muốn
chặn các signal khác không được gửi đến, và bạn có thể làm điều này bằng
cách thêm chúng vào `sa_mask`. Đây là một "tập hợp", nghĩa là bạn có thể
thực hiện các phép toán tập hợp bình thường để thao tác chúng:
`sigemptyset()`, `sigfillset()`, `sigaddset()`, `sigdelset()`, và
`sigismember()`. Trong ví dụ này, chúng ta sẽ chỉ xóa tập hợp và không
chặn bất kỳ signal nào khác.

Ví dụ luôn hữu ích! Đây là một ví dụ xử lý `SIGINT`, có thể được gửi
bằng cách nhấn `^C`, có tên là [flx[`sigint.c`|sigint.c]]:

``` {.c .numberLines}
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <signal.h>

void sigint_handler(int sig)
{
    (void)sig;
    const char msg[] = "Ahhh! SIGINT!\n";
    write(1, msg, sizeof msg  - 1);
}

int main(void)
{
    char s[200];
    struct sigaction sa = {
        .sa_handler = sigint_handler,
        .sa_flags = 0, // or SA_RESTART
    };
    sigemptyset(&sa.sa_mask);

    if (sigaction(SIGINT, &sa, NULL) == -1) {
        perror("sigaction");
        exit(1);
    }

    printf("Enter a string:\n");

    if (fgets(s, sizeof s, stdin) == NULL)
        perror("fgets");
    else 
        printf("You entered: %s\n", s);

    return 0;
}
```

Chương trình này có hai hàm: `main()` thiết lập signal handler (sử dụng
lệnh gọi `sigaction()`), và `sigint_handler()` là bản thân signal handler.

Điều gì xảy ra khi bạn chạy nó? Nếu bạn đang nhập một chuỗi và nhấn
`^C`, lệnh gọi `gets()` thất bại và đặt biến toàn cục `errno` thành
`EINTR`. Ngoài ra, `sigint_handler()` được gọi và thực hiện công việc
của nó, vì vậy bạn thực sự thấy:

```
Enter a string:
the quick brown fox jum^CAhhh! SIGINT!
fgets: Interrupted system call
```

Và rồi nó thoát. Này---đây là kiểu handler gì vậy, nếu nó chỉ thoát
ra bất kể thế nào?

Thực ra, có một vài điều đang diễn ra ở đây. Đầu tiên, bạn sẽ nhận thấy
rằng signal handler đã được gọi, vì nó in ra "Ahhh! SIGINT!" Nhưng sau
đó `fgets()` trả về lỗi, cụ thể là `EINTR`, hay "Interrupted system
call". Thấy đó, một số system call có thể bị ngắt bởi signal, và khi
điều này xảy ra, chúng trả về lỗi. Bạn có thể thấy code như thế này
(đôi khi được trích dẫn như là một cách dùng `goto` có thể bỏ qua):

``` {.c}
restart:
    if (some_system_call() == -1) {
        if (errno == EINTR) goto restart;
        perror("some_system_call");
        exit(1);
    }
```

Thay vì dùng `goto` như vậy, bạn có thể đặt `sa_flags` để bao gồm
`SA_RESTART`. Ví dụ, nếu chúng ta thay đổi code handler `SIGINT` thành:

``` {.c}
    sa.sa_flags = SA_RESTART;
```

Thì kết quả chạy của chúng ta trông như thế này hơn:

```
Enter a string:
Hello^CAhhh! SIGINT!
Er, hello!^CAhhh! SIGINT!
This time fer sure!
You entered: This time fer sure!
```

Một số system call có thể bị ngắt, và một số có thể được khởi động lại.
Điều này phụ thuộc vào hệ thống.

## Còn `signal()` thì sao

ANSI C định nghĩa một hàm gọi là `signal()` có thể được dùng để bắt
signal. Nó không đáng tin cậy hoặc đầy đủ tính năng như `sigaction()`,
vì vậy việc sử dụng `signal()` thường không được khuyến khích.

## Một số signal để bạn trở nên nổi tiếng

Đây là danh sách các signal bạn (rất có thể) có sẵn:

|Signal|Mô tả|
|:-:|-|
|`SIGABRT`|Signal hủy tiến trình.|
|`SIGALRM`|Đồng hồ báo thức.|
|`SIGFPE`|Phép toán số học sai.|
|`SIGHUP`|Ngắt kết nối (Hangup).|
|`SIGILL`|Lệnh không hợp lệ.|
|`SIGINT`|Signal ngắt terminal.|
|`SIGKILL`|Kill (không thể bắt hoặc bỏ qua).|
|`SIGPIPE`|Ghi vào pipe mà không có ai đọc.|
|`SIGQUIT`|Signal thoát terminal.|
|`SIGSEGV`|Tham chiếu bộ nhớ không hợp lệ.|
|`SIGTERM`|Signal kết thúc tiến trình.|
|`SIGUSR1`|Signal do người dùng định nghĩa 1.|
|`SIGUSR2`|Signal do người dùng định nghĩa 2.|
|`SIGCHLD`|Tiến trình con kết thúc hoặc bị dừng.|
|`SIGCONT`|Tiếp tục thực thi, nếu đã bị dừng.|
|`SIGSTOP`|Dừng thực thi (không thể bắt hoặc bỏ qua).|
|`SIGTSTP`|Signal dừng terminal.|
|`SIGTTIN`|Tiến trình nền đang cố đọc.|
|`SIGTTOU`|Tiến trình nền đang cố ghi.|
|`SIGBUS`|Lỗi bus.|
|`SIGPOLL`|Sự kiện có thể polling.|
|`SIGPROF`|Hết thời gian đếm profiling.|
|`SIGSYS`|System call không hợp lệ.|
|`SIGTRAP`|Bẫy trace/breakpoint.|
|`SIGURG`|Dữ liệu băng thông cao có sẵn tại socket.|
|`SIGVTALRM`|Hết thời gian đồng hồ ảo.|
|`SIGXCPU`|Vượt quá giới hạn thời gian CPU.|
|`SIGXFSZ`|Vượt quá giới hạn kích thước file.|

Mỗi signal có default signal handler riêng của nó, hành vi của chúng
được định nghĩa trong các trang man trên hệ thống của bạn.

## Những Con Rồng của Reentrancy

Nếu bạn đang bận làm gì đó với dữ liệu global hoặc static (gọi biến đó
là `alvin`) và rồi bạn bị ngắt, điều gì xảy ra nếu handler *cũng* sửa
đổi `alvin`? Và rồi handler trả về và `alvin` đã bị sửa đổi sau lưng
bạn! Và hàm của bạn không có cách nào biết điều đó! Tệ hơn, các cấu
trúc dữ liệu lớn có thể chỉ được ghi _một phần_ khi handler được gọi,
dẫn đến rách dữ liệu và trạng thái hỗn loạn khủng khiếp.

Chúng ta gọi đây là _vấn đề reentrancy_.

Điều đó có nghĩa là gì? Nếu tôi được phép, tôi sẽ lười biếng trích dẫn
[flw[bài viết Wikipedia về reentrancy|Reentrancy_(computing)]]:

> Reentrant code được thiết kế để an toàn và có thể dự đoán khi nhiều
> instance của cùng một hàm được gọi đồng thời hoặc liên tiếp nhanh
> chóng. Một chương trình máy tính hoặc chương trình con được gọi là
> reentrant nếu nhiều lần gọi có thể chạy đồng thời an toàn trên nhiều
> processor, hoặc nếu trên hệ thống đơn processor, việc thực thi của nó
> có thể bị ngắt và một lần thực thi mới có thể được khởi động an toàn
> (nó có thể được "re-entered"). Sự ngắt có thể được gây ra bởi hành
> động nội bộ như nhảy hoặc gọi [...], hoặc bởi hành động bên ngoài
> như một ngắt hoặc signal.

[flx[Đây là một ví dụ minh họa|sigcount.c]], liệt kê một phần bên dưới.
Hàm `increment()` không phải reentrant đối với các signal bất đồng bộ.

Hãy tưởng tượng hàm `increment()` từ từ tăng `count` toàn cục. Nhưng
chờ đã! Nếu signal handler kích hoạt lúc này, nó sẽ đặt `count` thành
một giá trị mà `increment()` không mong đợi! Và rồi mọi thứ sẽ nổ tung.

(Chúng ta sẽ đến `volatile sig_atomic_t` sau; bây giờ chỉ cần giả sử
đó là `int`.)

``` {.c}
volatile sig_atomic_t count;

void handler(int sig)
{
    (void)sig;

    count = 123;
}

void increment(void)
{
    int next_count = count + 1;

    printf("Count is %d, next should be %d\n", count, next_count);

    // Sleep to slow down time to demo the problem
    sleep(2);
    count++;

    if (count == next_count)
        puts("Everything is swell!");
    else
        printf("%d != %d! Aaa! ERROR DOES NOT COMPUTE!\n", count,
            next_count);
}
```

Bài học của bạn: bất cứ khi nào bạn dựa vào một loại trạng thái chia sẻ
nào đó, bạn có thể gặp rắc rối với signal nếu signal handler cũng sửa
đổi trạng thái chia sẻ đó.

[flx[Đây là một ví dụ khác sử dụng `strtok()`|sigstrtok.c]], là một hàm
nổi tiếng về tính không-reentrant.

``` {.c}
void handler(int sig)
{
    (void)sig;

    char x[] = "Hello, world!";
    char *token;

    if ((token = strtok(x, " ")) != NULL) do {
        write(1, "In handler: ", 12);
        write(1, token, strlen(token));
        write(1, "\n", 1);
    } while ((token = strtok(NULL, " ")) != NULL);
}

void tokenizer(void)
{
    char s[] = "The quick brown fox jumped over the lazy dogs";
    char *token;

    if ((token = strtok(s, " ")) != NULL) do {
        printf("In main: %s\n", token);
        // Sleep to slow down time to demo the problem
        sleep(1);
    } while ((token = strtok(NULL, " ")) != NULL);

    puts("Done tokenizing");
}
```

Giả sử rằng hai giây sau khi vào hàm `tokenizer()`, signal handler được
gọi. `handler()` thực hiện tokenize riêng trên chuỗi của nó và in các
token[^2baf].

[^2baf]: Và nó dùng `write()` vì `printf()` không phải reentrant!

Nếu mọi thứ diễn ra tốt và hợp lý, chúng ta sẽ thấy đầu ra này (nhưng
thực tế không phải vậy):

``` {.default}
In main: The
In main: quick
In handler: Hello,
In handler: world!
In main: brown
In main: fox
In main: jumped
In main: over
In main: the
In main: lazy
In main: dogs
Done tokenizing
```

Thấy signal xảy ra, được xử lý, và `tokenizer()` tiếp tục từ chỗ đã
dừng không? Tuyệt vời đúng không?

Thay vào đó chúng ta thấy điều này (có lẽ):

``` {.default}
In main: The
In main: quick
In handler: Hello,
In handler: world!
Done tokenizing
```

Phần còn lại đâu rồi?

`strtok()` duy trì một số trạng thái nội bộ trong một biến `static`.
Hàm `tokenize()` của chúng ta đang mong đợi trạng thái ở một trạng thái
nhất định, và signal handler đã ghi đè lên nó, khiến `tokenize()` hoạt
động sai.

Và điều này làm cho `strtok()` không-reentrant (và do liên kết,
`tokenize()` cũng không-reentrant).

Nhưng cách sửa thì dễ. Chúng ta chỉ cần một phiên bản reentrant của
`strtok()` không có trạng thái chia sẻ nội bộ. Và chúng ta có một cái
trong `strtok_r()`. Với hàm đó, *chúng ta* sở hữu trạng thái và chúng
ta truyền nó vào cho `strtok_r()` sử dụng. Mọi phần của code muốn có
vòng lặp `strtok_r()` sẽ có trạng thái riêng và không ai giẫm lên chân
của người khác.

Đây là code cho `strtok_r()` trong hàm `tokenizer()` (tương tự cho hàm
`handler()`):

``` {.c}
    char *lasts;

    if ((token = strtok_r(s, " ", &lasts)) != NULL) do {
        printf("In main: %s\n", token);
        // Sleep to slow down time to demo the problem
        sleep(1);
    } while ((token = strtok_r(NULL, " ", &lasts)) != NULL);
```

Thấy cách chúng ta theo dõi trạng thái của mình trong `lasts` không?
Nếu bạn thay thế tất cả `strtok()` bằng `strtok_r()` trong chương trình
demo, nó sẽ hoạt động đúng vì tất cả chức năng được sử dụng bởi cả
`handler()` và `tokenizer()` đều là reentrant.

## Dữ liệu Global Chia sẻ

Bạn không thể an toàn thay đổi bất kỳ dữ liệu chia sẻ nào (ví dụ
global), với một ngoại lệ đáng chú ý: các biến được khai báo là storage
class và kiểu `volatile sig_atomic_t`. Đây là một kiểu integer giữ một
số phạm vi giá trị; spec C đảm bảo rằng bạn sẽ ít nhất có thể giữ 0 đến
127, bao gồm cả hai đầu. Nhưng phạm vi thực tế phụ thuộc vào hệ thống
và liệu kiểu có dấu hay không. (Bạn có thể xem `SIG_ATOMIC_MIN` và
`SIG_ATOMIC_MAX` để biết giới hạn của mình.)

Spec rất thận trọng. Về cơ bản nó nói bạn đang hành động rất tệ nếu bạn
làm bất cứ điều gì với dữ liệu global ngoài việc gán vào một biến kiểu
`volatile sig_atomic_t`. Nhưng điều đó không _hoàn toàn_ đúng. _Có lẽ_
an toàn khi đọc từ biến cũng vậy, nhưng hãy lưu ý rằng ngay khi bạn đọc
và ghi vào cùng một biến, bạn chắc chắn đang mở bản thân cho một số
điều kiện race tùy thuộc vào ai khác đọc và sửa đổi các giá trị đó.

Một ngoại lệ khác là dữ liệu global chia sẻ không bao giờ thay đổi. Nếu
bạn thiết lập một số biến global trước khi signal handler được cài đặt,
và bạn không bao giờ thay đổi các giá trị đó, thì signal handler có thể
đọc chúng một cách tự do. Chúng có thể thuộc bất kỳ kiểu nào.

Đây là một ví dụ xử lý `SIGUSR1` bằng cách đặt một cờ global, sau đó
được kiểm tra trong vòng lặp chính để xem liệu handler đã được gọi chưa.
Đây là [flx[`sigusr.c`|sigusr.c]]:

``` {.c .numberLines}
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <signal.h>

volatile sig_atomic_t got_usr1;

void sigusr1_handler(int sig)
{
    got_usr1 = 1;
}

int main(void)
{
    struct sigaction sa = {
        .sa_handler = sigusr1_handler,
        .sa_flags = 0, // or SA_RESTART
    };
    sigemptyset(&sa.sa_mask);

    got_usr1 = 0;

    if (sigaction(SIGUSR1, &sa, NULL) == -1) {
        perror("sigaction");
        exit(1);
    }

    while (!got_usr1) {
        printf("PID %d: working hard...\n", getpid());
        sleep(1);
    }

    printf("Done in by SIGUSR1!\n");

    return 0;
}
```

Khởi động nó trong một cửa sổ, rồi dùng `kill -USR1` trong cửa sổ khác
để kết thúc nó. Chương trình `sigusr` tiện lợi in ra process ID của nó
để bạn có thể truyền nó vào `kill`:

```
$ sigusr
PID 5023: working hard...
PID 5023: working hard...
PID 5023: working hard...
```

Sau đó trong cửa sổ kia, gửi cho nó signal `SIGUSR1`:

```
$ kill -USR1 5023
```

Và chương trình sẽ phản hồi:

```
PID 5023: working hard...
PID 5023: working hard...
Done in by SIGUSR1!
```

(Và phản hồi sẽ ngay lập tức ngay cả khi `sleep()` vừa được gọi---`sleep()`
bị ngắt bởi signal.)

Việc cấu trúc code theo cách này hơi phản trực giác. Chẳng phải handler
nên có tất cả logic xử lý và một đoạn code khác hay sao? Điều gì xảy ra
nếu signal được phát khi code khác đang chạy mà không thể xử lý nó?

Đó là một nhược điểm nhỏ, nhưng cấu trúc code theo cách này có một lợi
ích lớn: *tạm biệt, vấn đề reentrancy!* Và điều đó không hề tệ.

### Độ an toàn signal bất đồng bộ

Trước những cạm bẫy reentrancy bạn có thể gặp, bạn phải cẩn thận khi
thực hiện các lệnh gọi hàm trong signal handler của mình, và thực sự,
khi handler của bạn sửa đổi bất kỳ trạng thái global nào mà các hàm
khác có thể đang sử dụng.

Các hàm đó phải _an toàn với signal bất đồng bộ (async-signal-safe)_,
điều này thường có nghĩa là hàm không làm bất cứ điều gì có thể gây ra
vấn đề reentrancy.

Nói chung, bạn có thể không an toàn với signal bất đồng bộ nếu bạn làm
bất kỳ điều nào trong số này:

* Sửa đổi một biến global không-atomic trong hàm của bạn.
* Đọc một biến global không-constant mà không phải atomic.
* Dùng dữ liệu `static` trong hàm hoặc trong handler của bạn.
* Gọi bất kỳ hàm nào khác không phải async-signal-safe.

Khá hạn chế.

Bạn có thể tò mò, ví dụ, tại sao signal handler trong ví dụ trước của
tôi gọi `write()` để xuất thông báo thay vì `printf()`. Câu trả lời là
POSIX nói rằng `write()` là async-signal-safe (vì vậy an toàn khi gọi
từ bên trong handler), trong khi `printf()` thì không.

Các hàm thư viện và system call là async-signal-safe và có thể được gọi
từ bên trong signal handler của bạn là (hít thở):

`_Exit()`, `_exit()`, `abort()`, `accept()`, `access()`, `aio_error()`,
`aio_return()`, `aio_suspend()`, `alarm()`, `bind()`, `cfgetispeed()`,
`cfgetospeed()`, `cfsetispeed()`, `cfsetospeed()`, `chdir()`, `chmod()`,
`chown()`, `clock_gettime()`, `close()`, `connect()`, `creat()`,
`dup()`, `dup2()`, `execle()`, `execve()`, `fchmod()`, `fchown()`,
`fcntl()`, `fdatasync()`, `fork()`, `fpathconf()`, `fstat()`, `fsync()`,
`ftruncate()`, `getegid()`, `geteuid()`, `getgid()`, `getgroups()`,
`getpeername()`, `getpgrp()`, `getpid()`, `getppid()`, `getsockname()`,
`getsockopt()`, `getuid()`, `kill()`, `link()`, `listen()`, `lseek()`,
`lstat()`, `mkdir()`, `mkfifo()`, `open()`, `pathconf()`, `pause()`,
`pipe()`, `poll()`, `posix_trace_event()`, `pselect()`, `raise()`,
`read()`, `readlink()`, `recv()`, `recvfrom()`, `recvmsg()`, `rename()`,
`rmdir()`, `select()`, `sem_post()`, `send()`, `sendmsg()`, `sendto()`,
`setgid()`, `setpgid()`, `setsid()`, `setsockopt()`, `setuid()`,
`shutdown()`, `sigaction()`, `sigaddset()`, `sigdelset()`,
`sigemptyset()`, `sigfillset()`, `sigismember()`, `sleep()`, `signal()`,
`sigpause()`, `sigpending()`, `sigprocmask()`, `sigqueue()`, `sigset()`,
`sigsuspend()`, `sockatmark()`, `socket()`, `socketpair()`, `stat()`,
`symlink()`, `sysconf()`, `tcdrain()`, `tcflow()`, `tcflush()`,
`tcgetattr()`, `tcgetpgrp()`, `tcsendbreak()`, `tcsetattr()`,
`tcsetpgrp()`, `time()`, `timer_getoverrun()`, `timer_gettime()`,
`timer_settime()`, `times()`, `umask()`, `uname()`, `unlink()`,
`utime()`, `wait()`, `waitpid()`, and `write()`.

Tất nhiên, bạn có thể gọi các hàm của riêng mình từ bên trong signal
handler (miễn là chúng là async-signal-safe và không gọi bất kỳ hàm
không-async-signal-safe nào).

Trong chương tiếp theo, chúng ta sẽ xem xét một số pattern để phản ứng
an toàn khi một signal được phát.

## Những Gì Tôi Đã Lướt Qua

Hầu như tất cả mọi thứ. Có hàng tấn cờ, realtime signal, kết hợp signal
với thread, che giấu signal, `longjmp()` và signal, và nhiều hơn nữa. Tôi
có một chương tiếp theo với tài liệu chuyên sâu hơn, nhưng tôi có thể
tạo cả một hướng dẫn riêng chỉ từ chủ đề này!

Tất nhiên, đây chỉ là hướng dẫn "bắt đầu", nhưng trong nỗ lực cuối cùng
để cung cấp cho bạn thêm thông tin, đây là danh sách các trang man với
nhiều thông tin hơn:

Xử lý signal:

* [flm[`sigaction()`|sigaction.2]]
* [flm[`sigwait()`|sigwait.3]]
* [flm[`sigwaitinfo()`|sigwaitinfo.2]]
* [flm[`sigtimedwait()`|sigtimedwait.2]]
* [flm[`sigsuspend()`|sigsuspend.2]]
* [flm[`sigpending()`|sigpending.2]]

Gửi signal:

* [flm[`kill()`|kill.2]]
* [flm[`raise()`|raise.3]]
* [flm[`sigqueue()`|sigqueue.3]]

Các phép toán tập hợp:

* [flm[`sigemptyset()`|sigemptyset.3]]
* [flm[`sigfillset()`|sigfillset.3]]
* [flm[`sigaddset()`|sigaddset.3]]
* [flm[`sigdelset()`|sigdelset.3]]
* [flm[`sigismember()`|sigismember.3]]

Khác:

* [flm[`sigprocmask()`|sigprocmask.2]]
* [flm[`sigaltstack()`|sigaltstack.2]]
* [flm[`siginterrupt()`|siginterrupt.3]]
* [flm[`sigsetjmp()`|sigsetjmp.3]]
* [flm[`siglongjmp()`|siglongjmp.3]]
* [flm[`signal()`|signal.2]]
