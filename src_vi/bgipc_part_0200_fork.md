<!-- Beej's guide to IPC

# vim: ts=4:sw=4:nosi:et:tw=72
-->

<!-- ======================================================= -->
<!-- Fork -->
<!-- ======================================================= -->

# Nhập môn `fork()` {#fork}

"Fork" (dĩa), ngoài việc là một trong những từ trông ngày càng kỳ lạ hơn
sau khi bạn gõ đi gõ lại nhiều lần, còn đề cập đến cách Unix tạo ra các
tiến trình mới. Tài liệu này cung cấp một bài nhập môn nhanh và thực tế
về `fork()`, vì system call này sẽ xuất hiện trong các tài liệu IPC khác.
Nếu bạn đã biết hết về `fork()` rồi thì có thể bỏ qua tài liệu này.

<!-- ======================================================= -->
<!-- "Seek ye the Gorge of Eternal Peril" -->
<!-- ======================================================= -->

## "Hãy tìm đến Hẻm Núi Nguy Hiểm Muôn Đời"

`fork()` có thể được coi như là tờ vé đến với quyền năng. Quyền năng đôi
khi lại là tờ vé dẫn đến hủy diệt. Do đó, bạn phải cẩn thận khi mày mò
với `fork()` trên hệ thống của mình, đặc biệt khi mọi người đang gấp rút
làm đồ án cuối kỳ gần đến hạn và sẵn sàng "xử lý" bất kỳ thứ gì làm hệ
thống chết đứng. Không phải là bạn không bao giờ được chơi với `fork()`,
chỉ là bạn cần thận trọng. Nó giống như nuốt gươm vậy---nếu cẩn thận,
bạn sẽ không tự mổ bụng mình.

Vì bạn vẫn còn đây, tôi nghĩ tốt hơn là tôi nên nói thẳng vào vấn đề.
Như tôi đã nói, `fork()` là cách Unix khởi động các tiến trình mới. Về
cơ bản, cách hoạt động là thế này: tiến trình cha (tiến trình đã tồn
tại) `fork()` ra một tiến trình con (tiến trình mới). Tiến trình con nhận
được một _bản sao_ dữ liệu của cha. _Voila!_ Bạn có hai tiến trình từ
chỗ chỉ có một!

Tất nhiên, có đủ loại bẫy mà bạn phải đối phó khi `fork()` các tiến
trình, nếu không sysadmin của bạn sẽ nổi giận với bạn khi bạn làm đầy
bảng tiến trình của hệ thống và họ phải ấn nút reset máy.

Trước tiên, bạn cần biết điều gì đó về hành vi của tiến trình trong Unix.
Khi một tiến trình chết, nó không thực sự biến mất hoàn toàn. Nó đã chết
nên không còn chạy nữa, nhưng một mảnh nhỏ còn chờ đợi để tiến trình cha
thu dọn. Mảnh nhỏ này chứa giá trị trả về từ tiến trình con và một số
thứ linh tinh khác. Vì vậy sau khi tiến trình cha `fork()` ra một tiến
trình con, nó phải `wait()` (hoặc `waitpid()`) để chờ tiến trình con đó
thoát. Chính hành động `wait()` này mới cho phép tất cả những gì còn sót
lại của tiến trình con biến mất.

Tất nhiên, có một ngoại lệ cho quy tắc trên: tiến trình cha có thể bỏ
qua tín hiệu `SIGCHLD` (là `SIGCLD` trên một số hệ thống cũ hơn) và khi
đó nó sẽ không cần phải `wait()`. Điều này có thể được thực hiện (trên
các hệ thống hỗ trợ nó) như sau:

``` {.c}
main()
{
    signal(SIGCHLD, SIG_IGN);  /* now I don't have to wait()! */
    .
    .
    fork();fork();fork();  /* Rabbits, rabbits, rabbits! */
```

Bây giờ, khi một tiến trình con chết mà không được `wait()`, nó thường
sẽ hiển thị trong danh sách `ps` dưới dạng "`<defunct>`". Nó sẽ ở trạng
thái này cho đến khi tiến trình cha `wait()` nó, hoặc được xử lý như đã
đề cập bên dưới.

Bây giờ có một quy tắc khác bạn phải học: khi tiến trình cha chết trước
khi nó `wait()` tiến trình con (giả sử nó không bỏ qua `SIGCHLD`), tiến
trình con sẽ được nhận làm con của tiến trình `init` (PID 1). Đây không
phải là vấn đề nếu tiến trình con vẫn đang sống tốt và trong tầm kiểm
soát. Tuy nhiên, nếu tiến trình con đã ở trạng thái defunct rồi, chúng
ta sẽ gặp rắc rối. Vì tiến trình cha ban đầu không thể `wait()` nữa vì
nó đã chết. Vậy làm sao `init` biết để `wait()` các _tiến trình zombie_
này?

Câu trả lời: đó là phép thuật! Thực ra trên một số hệ thống, `init` định
kỳ hủy tất cả các tiến trình defunct mà nó sở hữu. Trên các hệ thống
khác, nó thẳng thừng từ chối trở thành cha của bất kỳ tiến trình defunct
nào, thay vào đó hủy chúng ngay lập tức. Nếu bạn đang dùng một trong các
hệ thống kiểu trước, bạn có thể dễ dàng viết một vòng lặp làm đầy bảng
tiến trình bằng các tiến trình defunct thuộc sở hữu của `init`. Sysadmin
của bạn sẽ vui lòng lắm đấy?

Nhiệm vụ của bạn: đảm bảo tiến trình cha của bạn hoặc bỏ qua `SIGCHLD`,
hoặc `wait()` tất cả các con mà nó đã `fork()`. Thực ra bạn không _luôn
luôn_ phải làm vậy (ví dụ nếu bạn đang khởi động một daemon hay gì đó),
nhưng hãy lập trình cẩn thận nếu bạn là người mới với `fork()`. Nếu
không, cứ thoải mái phóng thẳng lên tầng bình lưu.

Tóm lại: các con trở thành defunct cho đến khi cha `wait()`, trừ khi cha
đang bỏ qua `SIGCHLD`. Hơn nữa, các con (còn sống hoặc defunct) mà cha
chết mà không `wait()` chúng (một lần nữa giả sử cha không bỏ qua
`SIGCHLD`) sẽ trở thành con của tiến trình `init`, nơi xử lý chúng khá
thẳng tay.

<!-- ======================================================= -->
<!-- "I'm mentally prepared! Give me The Button!" -->
<!-- ======================================================= -->

## "Tôi đã sẵn sàng tinh thần! Cho tôi _Cái Nút_ đó!"

Được thôi! Đây là một [flx[ví dụ|fork1.c]] về cách sử dụng `fork()`:

``` {.c .numberLines}
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>

int main(void)
{
    pid_t pid;
    int rv;

    switch(pid = fork()) {
    case -1:
        perror("fork");  /* something went wrong */
        exit(1);         /* parent exits */

    case 0:
        printf(" CHILD: This is the child process!\n");
        printf(" CHILD: My PID is %d\n", getpid());
        printf(" CHILD: My parent's PID is %d\n", getppid());
        printf(" CHILD: Enter my exit status (make it small): ");
        scanf(" %d", &rv);
        printf(" CHILD: I'm outta here!\n");
        exit(rv);

    default:
        printf("PARENT: This is the parent process!\n");
        printf("PARENT: My PID is %d\n", getpid());
        printf("PARENT: My child's PID is %d\n", pid);
        printf("PARENT: I'm now waiting for my child to exit()...\n");
        wait(&rv);
        printf("PARENT: My child's exit status is: %d\n", WEXITSTATUS(rv));
        printf("PARENT: I'm outta here!\n");
    }

    return 0;
}
```

Có rất nhiều điều cần lưu ý từ ví dụ này, vậy ta cứ bắt đầu từ đầu nhé.

`pid_t` là kiểu tiến trình tổng quát. Trong Unix, đây là một `short`. Vì
vậy tôi gọi `fork()` và lưu giá trị trả về vào biến `pid`. `fork()` rất
dễ, vì nó chỉ có thể trả về ba giá trị:

|Giá trị trả về|Mô tả|
|:----------:|------------------------------------------------------------|
|`0`|Nếu nó trả về `0`, bạn là tiến trình con. Bạn có thể lấy PID của cha bằng cách gọi `getppid()`. Tất nhiên, bạn có thể lấy PID của chính mình bằng cách gọi `getpid()`.|
|`-1`|Nếu nó trả về `-1`, có điều gì đó đã xảy ra sai, và không có tiến trình con nào được tạo. Dùng `perror()` để xem điều gì đã xảy ra. Có lẽ bạn đã làm đầy bảng tiến trình---nếu bạn quay lại bạn sẽ thấy sysadmin đang đến với chiếc rìu cứu hỏa.|
|Bất kỳ giá trị nào khác|Bất kỳ giá trị nào khác được trả về bởi `fork()` có nghĩa là bạn là tiến trình cha và giá trị trả về là PID của con bạn. Đây là cách duy nhất để lấy PID của con bạn, vì không có lệnh `getcpid()` (hiển nhiên do mối quan hệ một-nhiều giữa cha và con.)|

Khi tiến trình con cuối cùng gọi `exit()`, giá trị trả về được truyền sẽ
đến tiến trình cha khi nó `wait()`. Như bạn có thể thấy từ lệnh `wait()`,
có sự kỳ lạ khi chúng ta in giá trị trả về. Cái `WEXITSTATUS()` này là
gì vậy? Đó là một macro trích xuất giá trị trả về thực sự của tiến trình
con từ giá trị mà `wait()` trả về. Đúng, còn nhiều thông tin ẩn trong
`int` đó. Tôi để bạn tự tra cứu.

"Làm thế nào," bạn hỏi, "`wait()` biết phải đợi tiến trình nào? Ý tôi
là, vì tiến trình cha có thể có nhiều con, `wait()` thực sự đợi cái nào?"
Câu trả lời đơn giản, bạn ơi: nó đợi cái nào thoát ra đầu tiên. Nếu cần,
bạn có thể chỉ định chính xác con nào cần đợi bằng cách gọi `waitpid()`
với PID của con bạn làm đối số.

Một điều thú vị khác cần lưu ý từ ví dụ trên là cả cha và con đều dùng
biến `rv`. Điều này có nghĩa là nó được chia sẻ giữa các tiến trình
không? _KHÔNG!_ Nếu vậy thì tôi đã không viết hết mọi thứ về IPC này.
_Mỗi tiến trình có bản sao riêng của tất cả các biến._ Còn nhiều thứ
khác cũng được sao chép, nhưng bạn sẽ phải đọc trang `man` để biết thêm.

Một lưu ý cuối về chương trình trên: tôi đã dùng câu lệnh switch để xử
lý `fork()`, và điều đó không phải là điển hình. Thông thường bạn sẽ
thấy câu lệnh <statement>if</statement> ở đó; đôi khi ngắn như:

``` {.c}
if (!fork()) {
        printf("I'm the child!\n");
        exit(0);
    } else {
        printf("I'm the parent!\n");
        wait(NULL);
    }
```

À phải---ví dụ trên cũng minh họa cách `wait()` nếu bạn không quan tâm
đến giá trị trả về của tiến trình con: chỉ cần gọi nó với `NULL` làm đối
số.

<!-- ======================================================= -->
<!-- Fork summary -->
<!-- ======================================================= -->

## Tóm tắt

Bây giờ bạn đã biết tất cả về hàm `fork()` oai phong! Nó hữu ích hơn
một túi giun ướt trong hầu hết các tình huống tính toán cường độ cao,
và bạn có thể gây ấn tượng với bạn bè ở các buổi tiệc. Tôi thề đấy. Thử
đi.
