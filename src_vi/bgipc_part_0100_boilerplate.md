# Giới thiệu
<!-- Beej's guide to IPC
# vim: ts=4:sw=4:nosi:et:tw=72
-->

<!-- No hyphenation -->
[nh[fork]]

<!-- ======================================================= -->
<!-- Introduction -->
<!-- ======================================================= -->

Bạn biết cái gì dễ không? `fork()` dễ lắm. Bạn có thể fork ra hàng loạt
tiến trình mới cả ngày và để chúng xử lý từng phần của bài toán một cách
song song. Tất nhiên, mọi chuyện sẽ đơn giản nhất khi các tiến trình không
cần giao tiếp với nhau trong lúc chạy mà cứ ngồi đó làm việc của mình.

Tuy nhiên, khi bạn bắt đầu `fork()` các tiến trình, bạn sẽ ngay lập tức
nghĩ đến những ứng dụng đa người dùng thú vị nếu các tiến trình có thể
nói chuyện với nhau dễ dàng. Vì vậy bạn thử tạo một mảng toàn cục rồi
`fork()` để xem nó có được chia sẻ không. (Tức là, xem liệu cả tiến
trình con lẫn tiến trình cha có dùng chung mảng đó không.) Và rồi dĩ
nhiên bạn phát hiện ra rằng tiến trình con có bản sao riêng của mảng,
còn tiến trình cha hoàn toàn không hay biết về bất kỳ thay đổi nào mà
tiến trình con thực hiện.

Làm thế nào để những "ông" này nói chuyện với nhau, chia sẻ cấu trúc dữ
liệu, và nhìn chung là hòa thuận với nhau? Tài liệu này thảo luận về một
số phương pháp _Giao tiếp Liên tiến trình_ (IPC) có thể thực hiện được
điều đó, trong đó một số phương pháp phù hợp hơn với những tác vụ nhất
định so với các phương pháp khác.

<!-- ======================================================= -->
<!-- Audience -->
<!-- ======================================================= -->

## Đối tượng độc giả

Nếu bạn biết C hoặc C++ và khá quen với môi trường Unix (hoặc môi trường
POSIX nào đó hỗ trợ các system call này) thì tài liệu này dành cho bạn.
Nếu bạn chưa quen lắm, thì cũng đừng lo---bạn vẫn có thể hiểu được. Tuy
nhiên tôi giả định rằng bạn có một lượng kinh nghiệm lập trình C nhất định.

Giống như [flbg[Hướng dẫn Lập trình Mạng của Beej sử dụng Internet
Sockets|bgnet]], những tài liệu này được thiết kế để làm bàn đạp đưa người
đọc nói trên vào lĩnh vực IPC bằng cách cung cấp một cái nhìn tổng quan
súc tích về các kỹ thuật IPC khác nhau. Đây không phải là bộ tài liệu đầy
đủ toàn diện về chủ đề này, theo bất kỳ nghĩa nào. Như tôi đã nói, mục
đích của nó chỉ đơn giản là giúp bạn có được chỗ đứng trong thế giới thú
vị của IPC.

<!-- ======================================================= -->
<!-- Platform and Compiler -->
<!-- ======================================================= -->
## Nền tảng và Trình biên dịch

Các ví dụ trong tài liệu này được biên dịch trên Linux bằng `gcc`. Chúng
cũng có thể biên dịch được ở bất kỳ nơi nào có trình biên dịch Unix tốt.

<!-- ======================================================= -->
<!-- Homepage -->
<!-- ======================================================= -->
## Trang chủ chính thức

Địa chỉ chính thức của tài liệu này là
[flbg[`https://beej.us/guide/bgipc/`|bgipc]].

<!-- ======================================================= -->
<!-- Email policy -->
<!-- ======================================================= -->
## Chính sách Email

Nhìn chung tôi sẵn lòng trả lời các câu hỏi qua email, vì vậy bạn cứ
thoải mái gửi thư, nhưng tôi không thể đảm bảo sẽ trả lời. Cuộc sống
của tôi khá bận rộn và đôi khi tôi thực sự không có thời gian để trả
lời câu hỏi của bạn. Trong những trường hợp đó, tôi thường chỉ xóa
email đi thôi. Không phải vì cá nhân; chỉ là tôi không bao giờ có đủ
thời gian để đưa ra câu trả lời chi tiết mà bạn cần.

Về nguyên tắc, câu hỏi càng phức tạp thì tôi càng ít có khả năng trả
lời. Nếu bạn thu hẹp câu hỏi của mình trước khi gửi và đảm bảo bao gồm
mọi thông tin liên quan (như nền tảng, trình biên dịch, thông báo lỗi bạn
gặp, và bất cứ thứ gì bạn nghĩ có thể giúp tôi xử lý sự cố), bạn sẽ có
nhiều khả năng nhận được phản hồi hơn.

Nếu bạn không nhận được phản hồi, hãy tiếp tục mày mò, cố tìm câu trả
lời, và nếu vẫn chưa ra thì viết lại cho tôi với những thông tin bạn đã
tìm được, biết đâu sẽ đủ để tôi giúp được.

Sau khi đã "dạy bảo" bạn về cách viết và không viết cho tôi, tôi chỉ
muốn nói rằng tôi _thực sự_ trân trọng tất cả những lời khen mà hướng
dẫn này đã nhận được trong nhiều năm qua. Đó là một nguồn động lực thực
sự, và tôi rất vui khi biết nó đang được dùng vào mục đích tốt đẹp!
`:-)` Cảm ơn bạn!

<!-- ======================================================= -->
<!-- Mirroring -->
<!-- ======================================================= -->

## Sao chép trang web

Bạn hoàn toàn được chào đón để sao chép trang web này, dù công khai hay
riêng tư. Nếu bạn sao chép công khai và muốn tôi đặt link đến trang của
bạn từ trang chính, hãy nhắn tôi tại
[`beej@beej.us`](mailto:beej@beej.us).

<!-- ======================================================= -->
<!-- Translators -->
<!-- ======================================================= -->

## Ghi chú cho Người dịch

Nếu bạn muốn dịch hướng dẫn này sang ngôn ngữ khác, hãy viết cho tôi tại
[`beej@beej.us`] và tôi sẽ đặt link đến bản dịch của bạn từ trang chính.
Bạn có thể tự do thêm tên và thông tin liên hệ của mình vào bản dịch.

Vui lòng lưu ý các hạn chế về giấy phép trong phần Bản quyền và Phân
phối bên dưới.

<!-- ======================================================= -->
<!-- Copyright -->
<!-- ======================================================= -->
## Bản quyền và Phân phối

Hướng dẫn Lập trình Mạng của Beej là Bản quyền © 2021 Brian "Beej
Jorgensen" Hall.

Với các ngoại lệ cụ thể đối với mã nguồn và bản dịch nêu dưới đây, tác
phẩm này được cấp phép theo Giấy phép Creative Commons
Attribution-Noncommercial-No Derivative Works 3.0. Để xem bản sao giấy
phép này, hãy truy cập
[`https://creativecommons.org/licenses/by-nc-nd/3.0/`](https://creativecommons.org/licenses/by-nc-nd/3.0/)
hoặc gửi thư đến Creative Commons, 171 Second Street, Suite 300, San
Francisco, California, 94105, USA.

Một ngoại lệ cụ thể đối với phần "Không được tạo Tác phẩm Phái sinh" của
giấy phép như sau: hướng dẫn này có thể được tự do dịch sang bất kỳ ngôn
ngữ nào, với điều kiện bản dịch phải chính xác và hướng dẫn được in lại
đầy đủ. Các hạn chế giấy phép tương tự áp dụng cho bản dịch cũng như bản
gốc. Bản dịch cũng có thể bao gồm tên và thông tin liên hệ của người dịch.

Mã nguồn C được trình bày trong tài liệu này được đưa vào phạm vi công
cộng và hoàn toàn không có bất kỳ hạn chế giấy phép nào.

Các nhà giáo dục hoàn toàn được khuyến khích giới thiệu hoặc cung cấp
bản sao của hướng dẫn này cho học sinh của họ.

Liên hệ [`beej@beej.us`](mailto:beej@beej.us) để biết thêm thông tin.
