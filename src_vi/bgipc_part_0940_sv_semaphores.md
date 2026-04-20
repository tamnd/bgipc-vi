<!-- Beej's guide to IPC

# vim: ts=4:sw=4:nosi:et:tw=72
-->

<!-- ======================================================= -->
<!-- Semaphores -->
<!-- ======================================================= -->

# Semaphore System V {#svsemaphores}

Bạn còn nhớ [khóa file](#flocking) không? Vâng, semaphore có thể được
coi như một cơ chế khóa advisory rất tổng quát. Bạn có thể dùng chúng
để kiểm soát truy cập vào file, [bộ nhớ dùng chung](#svshm), và thực ra
bất cứ thứ gì bạn muốn. Chức năng cơ bản của semaphore là bạn có thể
đặt nó, kiểm tra nó, hoặc chờ cho đến khi nó được xóa rồi đặt nó
("test-n-set"). Dù những thứ tiếp theo có phức tạp đến đâu, hãy nhớ ba
thao tác đó.

Tài liệu này sẽ cung cấp tổng quan về chức năng semaphore, và kết thúc
bằng một chương trình sử dụng semaphore để kiểm soát truy cập vào một
file. (Nhiệm vụ này, thực ra, có thể dễ dàng được xử lý bằng khóa file,
nhưng nó là một ví dụ tốt vì dễ hiểu hơn, chẳng hạn như bộ nhớ dùng
chung.)

<!-- ======================================================= -->
<!-- Grabbing some semaphores -->
<!-- ======================================================= -->

## Lấy Một Số Semaphore

Với System V IPC, bạn không lấy các semaphore đơn lẻ; bạn lấy _tập
hợp_ semaphore. Bạn có thể, tất nhiên, lấy một tập hợp semaphore chỉ
có một semaphore, nhưng điểm quan trọng là bạn có thể có cả một loạt
semaphore chỉ bằng cách tạo một tập hợp semaphore duy nhất.

Làm thế nào bạn tạo tập hợp semaphore? Nó được thực hiện bằng một lệnh
gọi tới `semget()`, trả về ID semaphore (từ đây gọi là `semid`):


``` {.c}
#include <sys/sem.h>

int semget(key_t key, int nsems, int semflg);
```

`key` là gì? Đó là một định danh duy nhất được các tiến trình khác nhau
sử dụng để xác định tập hợp semaphore này. (Cái `key` này sẽ được tạo
ra bằng `ftok()`, mô tả trong [phần Hàng Đợi Tin Nhắn](#svmqftok).)

Đối số tiếp theo, `nsems`, là (bạn đoán đúng rồi!) số semaphore trong
tập hợp semaphore này. Số tối đa phụ thuộc hệ thống, nhưng có lẽ khoảng
32000. Nếu bạn cần nhiều hơn (đồ tham lam!), chỉ cần lấy thêm một tập
hợp semaphore khác. Bạn có thể truyền `0` nếu đang kết nối vào một tập
hợp semaphore đã tồn tại, nhưng phải chỉ định số dương nếu bạn đang tạo
một tập hợp semaphore mới.

Cuối cùng, có đối số `semflg`. Nó cho `semget()` biết quyền trên tập
hợp semaphore mới là gì, bạn đang tạo tập mới hay chỉ muốn kết nối vào
tập đã có, và các thứ khác mà bạn có thể tìm hiểu. Để tạo một tập mới,
quyền có thể được OR theo bit với `IPC_CREAT`.

Đây là một lệnh gọi ví dụ tạo `key` bằng `ftok()` và tạo một tập hợp
10 semaphore, với quyền 666 (`rw-rw-rw-`):

``` {.c}
#include <sys/ipc.h>
#include <sys/sem.h>

key_t key;
int semid;

key = ftok("/home/beej/somefile", 'E');
semid = semget(key, 10, 0666 | IPC_CREAT);
```

Chúc mừng! Bạn vừa tạo một tập hợp semaphore mới! Sau khi chạy chương
trình, bạn có thể kiểm tra bằng lệnh `ipcs`. (Đừng quên xóa nó khi
dùng xong bằng `ipcrm`!)

Chờ đã! Cảnh báo! _¡Advertencia! ¡No pongas las manos en la tolva!_
(Đó là câu tiếng Tây Ban Nha duy nhất tôi học được khi làm việc ở Pizza
Hut năm 1990. Nó được in trên máy cán bột.) Hãy chú ý điều này:

Khi bạn lần đầu tạo một số semaphore, chúng đều chưa được khởi tạo;
cần một lệnh gọi khác để đánh dấu chúng là trống (cụ thể là `semop()`
hoặc `semctl()`---xem các phần tiếp theo.) Điều này có nghĩa là gì? Ý
nghĩa là việc tạo semaphore không phải _atomic_ (nói cách khác, nó không
phải là một quá trình một bước). Nếu hai tiến trình đang cố tạo, khởi
tạo và sử dụng semaphore cùng một lúc, một điều kiện race có thể xảy ra.

Một cách để vượt qua khó khăn này là có một tiến trình khởi tạo duy nhất
tạo và khởi tạo semaphore từ lâu trước khi các tiến trình chính bắt đầu
chạy. Tiến trình chính chỉ truy cập nó, không bao giờ tạo hay hủy nó.

Stevens đề cập đến vấn đề này là "lỗi chết người" của semaphore. Ông
giải quyết nó bằng cách tạo tập hợp semaphore với cờ `IPC_EXCL`. Nếu
tiến trình 1 tạo nó trước, tiến trình 2 sẽ trả về lỗi trong lệnh gọi
(với `errno` được đặt thành `EEXIST`.) Lúc đó, tiến trình 2 sẽ phải chờ
cho đến khi semaphore được khởi tạo bởi tiến trình 1. Làm sao biết được?
Hóa ra, nó có thể gọi `semctl()` lặp đi lặp lại với cờ `IPC_STAT`, và
xem thành viên `sem_otime` của cấu trúc `struct semid_ds` được trả về.
Nếu giá trị đó khác không, có nghĩa là tiến trình 1 đã thực hiện một
thao tác trên semaphore với `semop()`, có lẽ để khởi tạo nó.

Để xem ví dụ về điều này, hãy xem chương trình trình diễn
[flx[`semdemo.c`|semdemo.c]], bên dưới, trong đó tôi tái triển khai một
cách tổng quát [code của Stevens](http://www.kohala.com/start/unpv22e/unpv22e.html).

Trong thời gian đó, hãy chuyển sang phần tiếp theo và xem cách khởi tạo
các semaphore vừa tạo.

<!-- ======================================================= -->
<!-- Controlling semaphores -->
<!-- ======================================================= -->

## Kiểm Soát Semaphore Của Bạn Với `semctl()`

Sau khi bạn tạo các tập hợp semaphore, bạn phải khởi tạo chúng về một
giá trị dương để cho thấy tài nguyên đang sẵn sàng sử dụng. Hàm
`semctl()` cho phép bạn thực hiện thay đổi giá trị atomic cho các
semaphore riêng lẻ hoặc toàn bộ tập hợp semaphore.

``` {.c}
int semctl(int semid, int semnum, int cmd, ... /*arg*/);
```

`semid` là ID tập hợp semaphore bạn lấy từ lệnh gọi `semget()` trước
đó. `semnum` là ID của semaphore mà bạn muốn thao tác giá trị. `cmd` là
những gì bạn muốn làm với semaphore đó. Đối số cuối cùng, "`arg`", nếu
cần, phải là một `union semun`, sẽ được bạn định nghĩa trong code của
bạn là một trong những thứ sau:

``` {.c}
union semun {
    int val;               /* used for SETVAL only */
    struct semid_ds *buf;  /* used for IPC_STAT and IPC_SET */
    ushort *array;         /* used for GETALL and SETALL */
};
```

(Lưu ý rằng `union semun` bây giờ được định nghĩa trong các file header
của các hệ thống Linux hiện đại. Tuy nhiên, tôi không biết feature test
macro nào để xác định điều này, vì vậy chỉ định nghĩa union này nếu hệ
thống của bạn chưa có. Đọc tài liệu `semctl()` để biết thêm thông tin.)

Các trường khác nhau trong `union semun` được sử dụng tùy thuộc vào giá
trị của tham số `cmd` cho `semctl()` (danh sách một phần như sau---xem
trang man cục bộ của bạn để biết thêm):

|`cmd`|Hiệu ứng|
|:--------:|----------------------------------------------------------|
|`SETVAL`|Đặt giá trị của semaphore đã chỉ định thành giá trị trong thành viên `val` của `union semun` được truyền vào.|
|`GETVAL`|Trả về giá trị của semaphore đã cho.|
|`SETALL`|Đặt giá trị của tất cả semaphore trong tập hợp thành các giá trị trong mảng trỏ bởi thành viên `array` của `union semun` được truyền vào. Tham số `semnum` cho `semctl()` không được dùng.<|
|`GETALL`|Lấy giá trị của tất cả semaphore trong tập hợp và lưu chúng vào mảng trỏ bởi thành viên `array` của `union semun` được truyền vào. Tham số `semnum` cho `semctl()` không được dùng.|
|`IPC_RMID`|Xóa tập hợp semaphore đã chỉ định khỏi hệ thống. Tham số `semnum` bị bỏ qua.|
|`IPC_STAT`|Tải thông tin trạng thái về tập hợp semaphore vào cấu trúc `struct semid_ds` trỏ bởi thành viên `buf` của `union semun`.|

Để tham khảo, đây là nội dung (rút gọn) của `struct semid_ds` được dùng
trong `union semun`:

``` {.c}
struct semid_ds {
    struct ipc_perm sem_perm;  /* Ownership and permissions
    time_t          sem_otime; /* Last semop time */
    time_t          sem_ctime; /* Last change time */
    unsigned short  sem_nsems; /* No. of semaphores in set */
};
```

Ta sẽ dùng thành viên `sem_otime` đó sau khi ta viết `initsem()` trong
code mẫu bên dưới.

<!-- ======================================================= -->
<!-- semop(): Atomic power! -->
<!-- ======================================================= -->

## `semop()`: Sức Mạnh Atomic!

Tất cả các thao tác đặt, lấy, hoặc test-n-set một semaphore đều sử dụng
syscall `semop()`. Syscall này là đa năng, và chức năng của nó được điều
khiển bởi một cấu trúc được truyền vào nó, `struct sembuf`:

``` {.c}
/* Warning! Members might not be in this order! */

struct sembuf {
    ushort sem_num;
    short sem_op;
    short sem_flg;
};
```

Tất nhiên, `sem_num` là số của semaphore trong tập hợp mà bạn muốn thao
tác. Rồi, `sem_op` là những gì bạn muốn làm với semaphore đó. Nó mang
các ý nghĩa khác nhau, tùy thuộc vào `sem_op` là dương, âm, hay bằng
không, như được trình bày trong bảng sau:

|`sem_op`|Điều xảy ra|
|:------:|--------------------------------------------------------------|
|Âm|Phân bổ tài nguyên. Block tiến trình gọi cho đến khi giá trị của semaphore lớn hơn hoặc bằng giá trị tuyệt đối của `sem_op`. (Tức là chờ cho đến khi đủ tài nguyên được giải phóng bởi các tiến trình khác để tiến trình này có thể phân bổ.) Sau đó cộng (thực chất là trừ, vì nó âm) giá trị `sem_op` vào giá trị semaphore.|
|Dương|Giải phóng tài nguyên. Giá trị `sem_op` được cộng vào giá trị semaphore.|
|Không|Tiến trình này sẽ chờ cho đến khi semaphore đạt giá trị 0.|

Vậy, về cơ bản, những gì bạn làm là điền vào một `struct sembuf` với
bất kỳ giá trị nào bạn muốn, rồi gọi `semop()`, như thế này:

<!-- BOOKMARK -->

``` {.c}
int semop(int semid, struct sembuf *sops,
          unsigned int nsops);
```

Đối số `semid` là số lấy từ lệnh gọi `semget()`. Tiếp theo là `sops`,
là con trỏ tới `struct sembuf` bạn đã điền với các lệnh semaphore. Tuy
nhiên, nếu muốn, bạn có thể tạo một mảng các `struct sembuf` để thực
hiện một loạt các thao tác semaphore cùng một lúc. Cách `semop()` biết
bạn đang làm điều này là đối số `nsop`, cho biết có bao nhiêu `struct
sembuf` bạn đang gửi. Nếu bạn chỉ có một, hãy đặt `1` cho đối số này.

Một trường trong `struct sembuf` mà tôi chưa đề cập là trường `sem_flg`
cho phép chương trình chỉ định các cờ để sửa đổi thêm hiệu ứng của lệnh
gọi `semop()`.

Một trong số các cờ này là `IPC_NOWAIT`, như tên gợi ý, làm cho lệnh
gọi `semop()` trả về với lỗi `EAGAIN` nếu nó gặp tình huống thông
thường sẽ block. Điều này tốt cho các tình huống bạn muốn "thăm dò" xem
bạn có thể phân bổ tài nguyên hay không.

Một cờ rất hữu ích khác là cờ `SEM_UNDO`. Nó làm cho `semop()` ghi lại,
theo một cách nào đó, sự thay đổi được thực hiện đối với semaphore. Khi
chương trình thoát, kernel sẽ tự động hoàn tác tất cả các thay đổi được
đánh dấu bằng cờ `SEM_UNDO`. Tất nhiên, chương trình của bạn nên cố
gắng hết mức để giải phóng bất kỳ tài nguyên nào nó đánh dấu bằng
semaphore, nhưng đôi khi điều này không thể thực hiện được khi chương
trình của bạn nhận được `SIGKILL` hoặc một số sự cố khủng khiếp khác xảy
ra.

<!-- ======================================================= -->
<!-- Destroying a semaphore -->
<!-- ======================================================= -->

## Xóa Một Semaphore

Có hai cách để loại bỏ semaphore: một là dùng lệnh Unix `ipcrm`. Cách
kia là thông qua lệnh gọi `semctl()` với `cmd` được đặt thành `IPC_RMID`.

Về cơ bản, bạn muốn gọi `semctl()` và đặt `semid` thành ID semaphore
mà bạn muốn xóa. `cmd` nên được đặt thành `IPC_RMID`, cho `semctl()`
biết xóa tập hợp semaphore này. Tham số `semnum` không có nghĩa gì trong
bối cảnh `IPC_RMID` và có thể chỉ cần đặt thành không.

Đây là một lệnh gọi ví dụ để xóa một tập hợp semaphore:

``` {.c}
int semid; 
.
.
semid = semget(...);
.
.
semctl(semid, 0, IPC_RMID);
```

Dễ như ăn kẹo.

<!-- ======================================================= -->
<!-- Semaphore: Sample Programs -->
<!-- ======================================================= -->

## Chương Trình Mẫu

Có hai chương trình. Chương trình đầu tiên, `semdemo.c`, tạo semaphore
nếu cần thiết, và thực hiện một số thao tác khóa file giả tạo trên nó
trong một bài trình diễn rất giống bài trong tài liệu [Khóa File](#flocking).
Chương trình thứ hai, `semrm.c` dùng để xóa semaphore (một lần nữa,
`ipcrm` có thể được dùng để thực hiện điều này.)

Ý tưởng là chạy `semdemo.c` trong một vài cửa sổ và xem tất cả các tiến
trình tương tác như thế nào. Khi xong, dùng `semrm.c` để xóa semaphore.
Bạn cũng có thể thử xóa semaphore trong khi đang chạy `semdemo.c` chỉ
để xem các loại lỗi nào được tạo ra.

Đây là [flx[`semdemo.c`|semdemo.c]], bao gồm một hàm có tên `initsem()`
vượt qua các điều kiện race của semaphore theo phong cách Stevens:

``` {.c .numberLines}
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/sem.h>

#define MAX_RETRIES 10

#ifdef NEED_SEMUN
/* Defined in sys/sem.h as required by POSIX now */
union semun {
    int val;
    struct semid_ds *buf;
    ushort *array;
};
#endif

/*
** initsem() -- more-than-inspired by W. Richard Stevens' UNIX Network
** Programming 2nd edition, volume 2, lockvsem.c, page 295.
*/
int initsem(key_t key, int nsems)  /* key from ftok() */
{
    int i;
    union semun arg;
    struct semid_ds buf;
    struct sembuf sb;
    int semid;

    semid = semget(key, nsems, IPC_CREAT | IPC_EXCL | 0666);

    if (semid >= 0) { /* we got it first */
            sb.sem_op = 1; sb.sem_flg = 0;
            arg.val = 1;

            printf("press return\n"); getchar();

            for(sb.sem_num = 0; sb.sem_num < nsems; sb.sem_num++) { 
                    /* do a semop() to "free" the semaphores. */
                    /* this sets the sem_otime field, as needed below. */
                    if (semop(semid, &sb, 1) == -1) {
                            int e = errno;
                            semctl(semid, 0, IPC_RMID); /* clean up */
                            errno = e;
                            return -1; /* error, check errno */
                    }
            }

    } else if (errno == EEXIST) { /* someone else got it first */
            int ready = 0;

            semid = semget(key, nsems, 0); /* get the id */
            if (semid < 0) return semid; /* error, check errno */

            /* wait for other process to initialize the semaphore: */
            arg.buf = &buf;
            for(i = 0; i < MAX_RETRIES && !ready; i++) {
                    semctl(semid, nsems-1, IPC_STAT, arg);
                    if (arg.buf->sem_otime != 0) {
                            ready = 1;
                    } else {
                            sleep(1);
                    }
            }
            if (!ready) {
                    errno = ETIME;
                    return -1;
            }
    } else {
            return semid; /* error, check errno */
    }

    return semid;
}

int main(void)
{
    key_t key;
    int semid;
    struct sembuf sb;
    
    sb.sem_num = 0;
    sb.sem_op = -1;  /* set to allocate resource */
    sb.sem_flg = SEM_UNDO;

    if ((key = ftok("semdemo.c", 'J')) == -1) {
            perror("ftok");
            exit(1);
    }

    /* grab the semaphore set created by seminit.c: */
    if ((semid = initsem(key, 1)) == -1) {
            perror("initsem");
            exit(1);
    }

    printf("Press return to lock: ");
    getchar();
    printf("Trying to lock...\n");

    if (semop(semid, &sb, 1) == -1) {
            perror("semop");
            exit(1);
    }

    printf("Locked.\n");
    printf("Press return to unlock: ");
    getchar();

    sb.sem_op = 1; /* free resource */
    if (semop(semid, &sb, 1) == -1) {
            perror("semop");
            exit(1);
    }

    printf("Unlocked\n");

    return 0;
}
```

Đây là [flx[`semrm.c`|semrm.c]] để xóa semaphore khi bạn xong:

``` {.c .numberLines}
#include <stdlib.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/sem.h>

int main(void)
{
    key_t key;
    int semid;
    union semun arg;

    if ((key = ftok("semdemo.c", 'J')) == -1) {
            perror("ftok");
            exit(1);
    }

    /* grab the semaphore set created by seminit.c: */
    if ((semid = semget(key, 1, 0)) == -1) {
            perror("semget");
            exit(1);
    }

    /* remove it: */
    if (semctl(semid, 0, IPC_RMID, 0) == -1) {
            perror("semctl");
            exit(1);
    }

    return 0;
}
```

Thật thú vị không! Tôi chắc chắn bạn sẽ từ bỏ Quake^[Hoặc bất kỳ trò
chơi FPS gây nghiện nào hiện tại.] chỉ để chơi với những thứ semaphore
này cả ngày!

<!-- ======================================================= -->
<!-- Semaphore summary -->
<!-- ======================================================= -->

## Tóm Tắt

Có lẽ tôi đã nói nhẹ về tính hữu dụng của semaphore. Tôi đảm bảo với
bạn, chúng rất rất rất hữu ích trong tình huống đồng thời. Chúng thường
còn nhanh hơn cả khóa file thông thường. Ngoài ra, bạn có thể dùng
chúng trên những thứ khác không phải file, chẳng hạn như [Vùng Nhớ
Dùng Chung](#svshm)! Thực ra, đôi khi khó mà sống thiếu chúng, thẳng
thắn mà nói.

Bất cứ khi nào bạn có nhiều tiến trình chạy qua một đoạn code quan
trọng, bạn cần semaphore. Bạn có hàng tỷ cái---cứ dùng chúng đi.
