# Native-only (별도) and adjusted (조정) translations for the iOS catalog.
# Languages use the web codes; build_catalog.py maps them to Apple locale identifiers.
# A dict value with "one"/"few"/"many"/"other" is a plural variation on the %lld argument.
LANGS = ["en", "ja", "de", "fr", "id", "vi", "tr", "ru", "hi", "th", "pt-BR", "es-ES", "es-419",
         "zh-Hans", "zh-Hant-TW", "zh-Hant-HK"]

def P(one, other, few=None, many=None):
    d = {"one": one, "other": other}
    if few: d["few"] = few
    if many: d["many"] = many
    return d

T = {}

T["선택한 항목 삭제"] = {
    "en": "Delete selected items", "ja": "選択した項目を削除", "de": "Ausgewählte Elemente löschen",
    "fr": "Supprimer les éléments sélectionnés", "id": "Hapus item yang dipilih", "vi": "Xóa các mục đã chọn",
    "tr": "Seçili öğeleri sil", "ru": "Удалить выбранные элементы", "hi": "चुने गए आइटम मिटाएँ",
    "th": "ลบรายการที่เลือก", "pt-BR": "Excluir itens selecionados", "es-ES": "Eliminar elementos seleccionados",
    "es-419": "Eliminar elementos seleccionados", "zh-Hans": "删除所选项目", "zh-Hant-TW": "刪除所選項目",
    "zh-Hant-HK": "刪除所選項目"}

T["두 번 탭해 날짜를 바꿔요."] = {
    "en": "Double-tap to change the date.", "ja": "ダブルタップで日付を変更します。",
    "de": "Doppeltippen, um das Datum zu ändern.", "fr": "Touchez deux fois pour changer la date.",
    "id": "Ketuk dua kali untuk mengubah tanggal.", "vi": "Chạm hai lần để đổi ngày.",
    "tr": "Tarihi değiştirmek için iki kez dokun.", "ru": "Коснитесь дважды, чтобы изменить дату.",
    "hi": "तारीख बदलने के लिए दो बार टैप करें।", "th": "แตะสองครั้งเพื่อเปลี่ยนวันที่",
    "pt-BR": "Toque duas vezes para mudar a data.", "es-ES": "Toca dos veces para cambiar la fecha.",
    "es-419": "Toca dos veces para cambiar la fecha.", "zh-Hans": "轻点两下即可更改日期。",
    "zh-Hant-TW": "點兩下即可更改日期。", "zh-Hant-HK": "點兩下即可更改日期。"}

# Back from the editor: returns to the view it was opened from and keeps the draft.
T["홈으로, 초안 보관"] = {
    "en": "Back, keep draft", "ja": "下書きを残して戻る", "de": "Zurück, Entwurf behalten",
    "fr": "Retour, garder le brouillon", "id": "Kembali dan simpan draf", "vi": "Quay lại và giữ bản nháp",
    "tr": "Geri dön, taslağı sakla", "ru": "Назад, сохранить черновик", "hi": "वापस जाएँ, ड्राफ़्ट रखें",
    "th": "กลับและเก็บฉบับร่างไว้", "pt-BR": "Voltar e manter o rascunho", "es-ES": "Volver y conservar el borrador",
    "es-419": "Volver y conservar el borrador", "zh-Hans": "返回并保留草稿", "zh-Hant-TW": "返回並保留草稿",
    "zh-Hant-HK": "返回並保留草稿"}

T["두 번 탭해 수정해요."] = {
    "en": "Double-tap to edit.", "ja": "ダブルタップで編集します。", "de": "Doppeltippen zum Bearbeiten.",
    "fr": "Touchez deux fois pour modifier.", "id": "Ketuk dua kali untuk mengedit.", "vi": "Chạm hai lần để sửa.",
    "tr": "Düzenlemek için iki kez dokun.", "ru": "Коснитесь дважды, чтобы изменить.",
    "hi": "बदलने के लिए दो बार टैप करें।", "th": "แตะสองครั้งเพื่อแก้ไข", "pt-BR": "Toque duas vezes para editar.",
    "es-ES": "Toca dos veces para editar.", "es-419": "Toca dos veces para editar.",
    "zh-Hans": "轻点两下即可编辑。", "zh-Hant-TW": "點兩下即可編輯。", "zh-Hant-HK": "點兩下即可編輯。"}

T["시간 입력, 아래 선택기에서 골라요"] = {
    "en": "Time input. Choose a time in the picker below.", "ja": "時刻の入力。下のピッカーで選びます",
    "de": "Uhrzeit eingeben. Wähle sie unten aus.", "fr": "Saisie de l’heure. Choisissez-la ci-dessous.",
    "id": "Input waktu. Pilih di pemilih di bawah.", "vi": "Nhập giờ. Chọn ở bộ chọn bên dưới.",
    "tr": "Saat girişi. Aşağıdaki seçiciden seç.", "ru": "Ввод времени. Выберите его ниже.",
    "hi": "समय डालें। नीचे दिए चयनकर्ता से चुनें।", "th": "ป้อนเวลา เลือกจากตัวเลือกด้านล่าง",
    "pt-BR": "Horário. Escolha no seletor abaixo.", "es-ES": "Hora. Elígela en el selector de abajo.",
    "es-419": "Hora. Elígela en el selector de abajo.", "zh-Hans": "输入时间，请在下方选择器中选择",
    "zh-Hant-TW": "輸入時間，請在下方選擇器中選擇", "zh-Hant-HK": "輸入時間，請在下方選擇器中選擇"}

T["시간 %@"] = {
    "en": "Time %@", "ja": "時刻 %@", "de": "Uhrzeit %@", "fr": "Heure %@", "id": "Waktu %@", "vi": "Giờ %@",
    "tr": "Saat %@", "ru": "Время %@", "hi": "समय %@", "th": "เวลา %@", "pt-BR": "Horário %@", "es-ES": "Hora %@",
    "es-419": "Hora %@", "zh-Hans": "时间 %@", "zh-Hant-TW": "時間 %@", "zh-Hant-HK": "時間 %@"}

# VoiceOver: kind, then the value the person wrote.
T["%@ %@"] = {l: "%1$@, %2$@" for l in LANGS}
T["%@ %@"].update({"ja": "%1$@、%2$@", "zh-Hans": "%1$@，%2$@", "zh-Hant-TW": "%1$@，%2$@", "zh-Hant-HK": "%1$@，%2$@",
                   "th": "%1$@ %2$@"})

T["저장하지 못했어요.\n입력은 이 화면에 남아 있어요.\n저장 공간을 확인해 주세요."] = {
    "en": "Couldn’t save.\nYour entries are still on this screen.\nCheck your storage.",
    "ja": "保存できませんでした。\n入力した内容はこの画面に残っています。\nストレージの空き容量を確認してください。",
    "de": "Speichern fehlgeschlagen.\nDeine Eingaben bleiben auf diesem Bildschirm.\nPrüfe den Speicherplatz.",
    "fr": "Impossible d’enregistrer.\nVotre saisie reste sur cet écran.\nVérifiez l’espace de stockage.",
    "id": "Tidak dapat menyimpan.\nIsian Anda masih ada di layar ini.\nPeriksa ruang penyimpanan.",
    "vi": "Không lưu được.\nNội dung bạn nhập vẫn còn trên màn hình này.\nHãy kiểm tra dung lượng lưu trữ.",
    "tr": "Kaydedilemedi.\nGirdiklerin bu ekranda duruyor.\nDepolama alanını kontrol et.",
    "ru": "Не удалось сохранить.\nВведённое осталось на этом экране.\nПроверьте свободное место.",
    "hi": "सहेजा नहीं जा सका।\nआपकी जानकारी इसी स्क्रीन पर है।\nस्टोरेज जाँचें।",
    "th": "บันทึกไม่สำเร็จ\nสิ่งที่ป้อนยังอยู่บนหน้าจอนี้\nโปรดตรวจสอบพื้นที่เก็บข้อมูล",
    "pt-BR": "Não foi possível salvar.\nO que você digitou continua nesta tela.\nVerifique o armazenamento.",
    "es-ES": "No se ha podido guardar.\nLo que has escrito sigue en esta pantalla.\nRevisa el almacenamiento.",
    "es-419": "No se pudo guardar.\nLo que escribiste sigue en esta pantalla.\nRevisa el almacenamiento.",
    "zh-Hans": "无法保存。\n已输入的内容仍保留在此页面。\n请检查存储空间。",
    "zh-Hant-TW": "無法儲存。\n已輸入的內容仍保留在此畫面。\n請檢查儲存空間。",
    "zh-Hant-HK": "無法儲存。\n已輸入的內容仍保留在此畫面。\n請檢查儲存空間。"}

T["기록과 초안은 이 기기에 저장돼요. 앱 데이터를 지우면 함께 삭제돼요. 위치와 캘린더에 접근하지 않아요."] = {
    "en": "Notes and drafts are stored on this device and are deleted with the app’s data. Tokipin doesn’t access your location or calendar.",
    "ja": "記録と下書きはこの端末に保存され、アプリのデータを削除すると一緒に削除されます。位置情報やカレンダーにはアクセスしません。",
    "de": "Notizen und Entwürfe werden auf diesem Gerät gespeichert und mit den App-Daten gelöscht. Tokipin greift nicht auf Standort oder Kalender zu.",
    "fr": "Les notes et brouillons sont stockés sur cet appareil et supprimés avec les données de l’app. Tokipin n’accède ni à votre position ni à votre calendrier.",
    "id": "Catatan dan draf disimpan di perangkat ini dan ikut terhapus bersama data aplikasi. Tokipin tidak mengakses lokasi atau kalender Anda.",
    "vi": "Ghi chú và bản nháp được lưu trên thiết bị này và sẽ bị xóa cùng dữ liệu ứng dụng. Tokipin không truy cập vị trí hay lịch của bạn.",
    "tr": "Notlar ve taslaklar bu cihazda saklanır, uygulama verileriyle birlikte silinir. Tokipin konumuna veya takvimine erişmez.",
    "ru": "Записи и черновики хранятся на этом устройстве и удаляются вместе с данными приложения. Tokipin не обращается к геопозиции и календарю.",
    "hi": "नोट और ड्राफ़्ट इसी डिवाइस पर सहेजे जाते हैं और ऐप डेटा मिटाने पर साथ में मिट जाते हैं। Tokipin आपकी लोकेशन या कैलेंडर तक नहीं पहुँचता।",
    "th": "บันทึกและฉบับร่างเก็บไว้ในอุปกรณ์นี้ และจะถูกลบไปพร้อมข้อมูลแอป Tokipin ไม่เข้าถึงตำแหน่งหรือปฏิทินของคุณ",
    "pt-BR": "As anotações e rascunhos ficam neste dispositivo e são apagados com os dados do app. O Tokipin não acessa sua localização nem seu calendário.",
    "es-ES": "Las notas y los borradores se guardan en este dispositivo y se borran con los datos de la app. Tokipin no accede a tu ubicación ni a tu calendario.",
    "es-419": "Las notas y los borradores se guardan en este dispositivo y se borran con los datos de la app. Tokipin no accede a tu ubicación ni a tu calendario.",
    "zh-Hans": "记录和草稿保存在此设备上，删除应用数据时会一并删除。Tokipin 不会访问你的位置或日历。",
    "zh-Hant-TW": "紀錄和草稿儲存在這部裝置上，刪除 App 資料時會一併刪除。Tokipin 不會存取你的位置或行事曆。",
    "zh-Hant-HK": "記錄和草稿儲存在此裝置上，刪除 App 資料時會一併刪除。Tokipin 不會存取你的位置或日曆。"}

T["내보내지 못했어요. 다시 시도해 주세요."] = {
    "en": "Couldn’t export. Please try again.", "ja": "書き出せませんでした。もう一度お試しください。",
    "de": "Export fehlgeschlagen. Bitte versuche es erneut.", "fr": "Impossible d’exporter. Réessayez.",
    "id": "Tidak dapat mengekspor. Coba lagi.", "vi": "Không xuất được. Vui lòng thử lại.",
    "tr": "Dışa aktarılamadı. Lütfen tekrar dene.", "ru": "Не удалось экспортировать. Попробуйте ещё раз.",
    "hi": "एक्सपोर्ट नहीं हो सका। फिर से कोशिश करें।", "th": "ส่งออกไม่สำเร็จ โปรดลองอีกครั้ง",
    "pt-BR": "Não foi possível exportar. Tente de novo.", "es-ES": "No se ha podido exportar. Inténtalo de nuevo.",
    "es-419": "No se pudo exportar. Vuelve a intentarlo.", "zh-Hans": "无法导出，请重试。",
    "zh-Hant-TW": "無法匯出，請再試一次。", "zh-Hant-HK": "無法匯出，請再試一次。"}

T["Tokipin에 한마디"] = {
    "en": "Send us a note", "ja": "Tokipinにひとこと", "de": "Schreib uns", "fr": "Écrivez-nous",
    "id": "Kirim pesan ke Tokipin", "vi": "Gửi lời nhắn cho Tokipin", "tr": "Tokipin’e bir not gönder",
    "ru": "Написать Tokipin", "hi": "Tokipin को संदेश भेजें", "th": "ส่งข้อความถึง Tokipin",
    "pt-BR": "Fale com o Tokipin", "es-ES": "Escríbenos", "es-419": "Escríbenos", "zh-Hans": "给 Tokipin 留言",
    "zh-Hant-TW": "給 Tokipin 留言", "zh-Hant-HK": "給 Tokipin 留言"}

T["기록을 내보냈어요."] = {
    "en": "Notes exported.", "ja": "記録を書き出しました。", "de": "Notizen exportiert.", "fr": "Notes exportées.",
    "id": "Catatan sudah diekspor.", "vi": "Đã xuất ghi chú.", "tr": "Notlar dışa aktarıldı.",
    "ru": "Записи экспортированы.", "hi": "नोट एक्सपोर्ट हो गए।", "th": "ส่งออกบันทึกแล้ว",
    "pt-BR": "Anotações exportadas.", "es-ES": "Notas exportadas.", "es-419": "Notas exportadas.",
    "zh-Hans": "记录已导出。", "zh-Hant-TW": "紀錄已匯出。", "zh-Hant-HK": "記錄已匯出。"}

T["기록을 불러오지 못했어요"] = {
    "en": "Couldn’t load your notes", "ja": "記録を読み込めませんでした", "de": "Notizen konnten nicht geladen werden",
    "fr": "Impossible de charger vos notes", "id": "Tidak dapat memuat catatan", "vi": "Không tải được ghi chú",
    "tr": "Notlar yüklenemedi", "ru": "Не удалось загрузить записи", "hi": "नोट लोड नहीं हो सके",
    "th": "โหลดบันทึกไม่สำเร็จ", "pt-BR": "Não foi possível carregar as anotações",
    "es-ES": "No se han podido cargar las notas", "es-419": "No se pudieron cargar las notas",
    "zh-Hans": "无法载入记录", "zh-Hant-TW": "無法載入紀錄", "zh-Hant-HK": "無法載入記錄"}

T["기기에 저장된 기록을 읽을 수 없어요.\n잠시 후 다시 시도해 주세요."] = {
    "en": "The notes saved on this device can’t be read.\nPlease try again in a moment.",
    "ja": "この端末に保存された記録を読み込めません。\nしばらくしてからもう一度お試しください。",
    "de": "Die auf diesem Gerät gespeicherten Notizen können nicht gelesen werden.\nVersuche es gleich noch einmal.",
    "fr": "Impossible de lire les notes enregistrées sur cet appareil.\nRéessayez dans un instant.",
    "id": "Catatan yang tersimpan di perangkat ini tidak dapat dibaca.\nCoba lagi sebentar lagi.",
    "vi": "Không đọc được ghi chú đã lưu trên thiết bị này.\nVui lòng thử lại sau giây lát.",
    "tr": "Bu cihazda kayıtlı notlar okunamıyor.\nBiraz sonra tekrar dene.",
    "ru": "Не удаётся прочитать записи на этом устройстве.\nПопробуйте ещё раз чуть позже.",
    "hi": "इस डिवाइस पर सहेजे गए नोट पढ़े नहीं जा सके।\nकुछ देर बाद फिर से कोशिश करें।",
    "th": "อ่านบันทึกที่เก็บไว้ในอุปกรณ์นี้ไม่ได้\nโปรดลองอีกครั้งในอีกสักครู่",
    "pt-BR": "Não foi possível ler as anotações salvas neste dispositivo.\nTente de novo daqui a pouco.",
    "es-ES": "No se pueden leer las notas guardadas en este dispositivo.\nVuelve a intentarlo dentro de un momento.",
    "es-419": "No se pueden leer las notas guardadas en este dispositivo.\nVuelve a intentarlo en un momento.",
    "zh-Hans": "无法读取此设备上保存的记录。\n请稍后再试。",
    "zh-Hant-TW": "無法讀取這部裝置上儲存的紀錄。\n請稍後再試。",
    "zh-Hant-HK": "無法讀取此裝置上儲存的記錄。\n請稍後再試。"}

# Folded empty period in 월간: %1$@ and %2$@ are spoken months ("June 2017"), %3$lld the count.
T["%@부터 %@까지 기록 없는 %lld개월"] = {
    "en": P("%1$@ to %2$@, %3$lld month without notes", "%1$@ to %2$@, %3$lld months without notes"),
    "ja": "%1$@から%2$@まで、記録のない%3$lldか月",
    "de": P("%1$@ bis %2$@, %3$lld Monat ohne Notizen", "%1$@ bis %2$@, %3$lld Monate ohne Notizen"),
    "fr": P("De %1$@ à %2$@, %3$lld mois sans note", "De %1$@ à %2$@, %3$lld mois sans note", many="De %1$@ à %2$@, %3$lld mois sans note"),
    "id": "%1$@ sampai %2$@, %3$lld bulan tanpa catatan",
    "vi": "Từ %1$@ đến %2$@, %3$lld tháng không có ghi chú",
    "tr": "%1$@ – %2$@, notsuz %3$lld ay",
    "ru": P("С %1$@ по %2$@, %3$lld месяц без записей", "С %1$@ по %2$@, %3$lld месяца без записей",
            few="С %1$@ по %2$@, %3$lld месяца без записей", many="С %1$@ по %2$@, %3$lld месяцев без записей"),
    "hi": "%1$@ से %2$@ तक, बिना नोट वाले %3$lld महीने",
    "th": "%1$@ ถึง %2$@ ไม่มีบันทึก %3$lld เดือน",
    "pt-BR": P("De %1$@ a %2$@, %3$lld mês sem anotações", "De %1$@ a %2$@, %3$lld meses sem anotações", many="De %1$@ a %2$@, %3$lld meses sem anotações"),
    "es-ES": P("De %1$@ a %2$@, %3$lld mes sin notas", "De %1$@ a %2$@, %3$lld meses sin notas", many="De %1$@ a %2$@, %3$lld meses sin notas"),
    "es-419": P("De %1$@ a %2$@, %3$lld mes sin notas", "De %1$@ a %2$@, %3$lld meses sin notas", many="De %1$@ a %2$@, %3$lld meses sin notas"),
    "zh-Hans": "%1$@至%2$@，%3$lld 个月没有记录",
    "zh-Hant-TW": "%1$@至%2$@，%3$lld 個月沒有紀錄",
    "zh-Hant-HK": "%1$@至%2$@，%3$lld 個月沒有記錄"}

T["%@부터 %@까지 기록 없는 %lld년"] = {
    "en": P("%1$@ to %2$@, %3$lld year without notes", "%1$@ to %2$@, %3$lld years without notes"),
    "ja": "%1$@から%2$@まで、記録のない%3$lld年",
    "de": P("%1$@ bis %2$@, %3$lld Jahr ohne Notizen", "%1$@ bis %2$@, %3$lld Jahre ohne Notizen"),
    "fr": P("De %1$@ à %2$@, %3$lld an sans note", "De %1$@ à %2$@, %3$lld ans sans note", many="De %1$@ à %2$@, %3$lld ans sans note"),
    "id": "%1$@ sampai %2$@, %3$lld tahun tanpa catatan",
    "vi": "Từ %1$@ đến %2$@, %3$lld năm không có ghi chú",
    "tr": "%1$@ – %2$@, notsuz %3$lld yıl",
    "ru": P("С %1$@ по %2$@, %3$lld год без записей", "С %1$@ по %2$@, %3$lld года без записей",
            few="С %1$@ по %2$@, %3$lld года без записей", many="С %1$@ по %2$@, %3$lld лет без записей"),
    "hi": "%1$@ से %2$@ तक, बिना नोट वाले %3$lld साल",
    "th": "%1$@ ถึง %2$@ ไม่มีบันทึก %3$lld ปี",
    "pt-BR": P("De %1$@ a %2$@, %3$lld ano sem anotações", "De %1$@ a %2$@, %3$lld anos sem anotações", many="De %1$@ a %2$@, %3$lld anos sem anotações"),
    "es-ES": P("De %1$@ a %2$@, %3$lld año sin notas", "De %1$@ a %2$@, %3$lld años sin notas", many="De %1$@ a %2$@, %3$lld años sin notas"),
    "es-419": P("De %1$@ a %2$@, %3$lld año sin notas", "De %1$@ a %2$@, %3$lld años sin notas", many="De %1$@ a %2$@, %3$lld años sin notas"),
    "zh-Hans": "%1$@至%2$@，%3$lld 年没有记录",
    "zh-Hant-TW": "%1$@至%2$@，%3$lld 年沒有紀錄",
    "zh-Hant-HK": "%1$@至%2$@，%3$lld 年沒有記錄"}

T["%@, 기록 없는 해"] = {
    "en": "%@, no notes this year", "ja": "%@、記録のない年", "de": "%@, Jahr ohne Notizen", "fr": "%@, année sans note",
    "id": "%@, tahun tanpa catatan", "vi": "%@, năm không có ghi chú", "tr": "%@, notsuz yıl", "ru": "%@, год без записей",
    "hi": "%@, बिना नोट वाला साल", "th": "%@ ปีที่ไม่มีบันทึก", "pt-BR": "%@, ano sem anotações", "es-ES": "%@, año sin notas",
    "es-419": "%@, año sin notas", "zh-Hans": "%@，没有记录的一年", "zh-Hant-TW": "%@，沒有紀錄的一年", "zh-Hant-HK": "%@，沒有記錄的一年"}

T["%@, 기록 있음"] = {
    "en": "%@, has notes", "ja": "%@、記録あり", "de": "%@, mit Notizen", "fr": "%@, avec des notes", "id": "%@, ada catatan",
    "vi": "%@, có ghi chú", "tr": "%@, not var", "ru": "%@, есть записи", "hi": "%@, नोट हैं", "th": "%@ มีบันทึก",
    "pt-BR": "%@, com anotações", "es-ES": "%@, con notas", "es-419": "%@, con notas", "zh-Hans": "%@，有记录",
    "zh-Hant-TW": "%@，有紀錄", "zh-Hant-HK": "%@，有記錄"}

T["펼침"] = {
    "en": "Expanded", "ja": "展開中", "de": "Ausgeklappt", "fr": "Déplié", "id": "Diperluas", "vi": "Đang mở rộng",
    "tr": "Genişletildi", "ru": "Развёрнуто", "hi": "फैला हुआ", "th": "ขยายอยู่", "pt-BR": "Expandido", "es-ES": "Expandido",
    "es-419": "Expandido", "zh-Hans": "已展开", "zh-Hant-TW": "已展開", "zh-Hant-HK": "已展開"}
T["접힘"] = {
    "en": "Collapsed", "ja": "折りたたみ中", "de": "Eingeklappt", "fr": "Replié", "id": "Diciutkan", "vi": "Đang thu gọn",
    "tr": "Daraltıldı", "ru": "Свёрнуто", "hi": "समेटा हुआ", "th": "ย่ออยู่", "pt-BR": "Recolhido", "es-ES": "Contraído",
    "es-419": "Contraído", "zh-Hans": "已收起", "zh-Hant-TW": "已收合", "zh-Hant-HK": "已收起"}
T["두 번 탭해 접어요."] = {
    "en": "Double-tap to collapse.", "ja": "ダブルタップで折りたたみます。", "de": "Doppeltippen zum Einklappen.",
    "fr": "Touchez deux fois pour replier.", "id": "Ketuk dua kali untuk menciutkan.", "vi": "Chạm hai lần để thu gọn.",
    "tr": "Daraltmak için iki kez dokun.", "ru": "Коснитесь дважды, чтобы свернуть.", "hi": "समेटने के लिए दो बार टैप करें।",
    "th": "แตะสองครั้งเพื่อย่อ", "pt-BR": "Toque duas vezes para recolher.", "es-ES": "Toca dos veces para contraer.",
    "es-419": "Toca dos veces para contraer.", "zh-Hans": "轻点两下即可收起。", "zh-Hant-TW": "點兩下即可收合。",
    "zh-Hant-HK": "點兩下即可收起。"}
T["두 번 탭해 펼쳐요."] = {
    "en": "Double-tap to expand.", "ja": "ダブルタップで展開します。", "de": "Doppeltippen zum Ausklappen.",
    "fr": "Touchez deux fois pour déplier.", "id": "Ketuk dua kali untuk memperluas.", "vi": "Chạm hai lần để mở rộng.",
    "tr": "Genişletmek için iki kez dokun.", "ru": "Коснитесь дважды, чтобы развернуть.", "hi": "फैलाने के लिए दो बार टैप करें।",
    "th": "แตะสองครั้งเพื่อขยาย", "pt-BR": "Toque duas vezes para expandir.", "es-ES": "Toca dos veces para expandir.",
    "es-419": "Toca dos veces para expandir.", "zh-Hans": "轻点两下即可展开。", "zh-Hant-TW": "點兩下即可展開。",
    "zh-Hant-HK": "點兩下即可展開。"}

T["검색어 지우기"] = {
    "en": "Clear search", "ja": "検索キーワードを消去", "de": "Suche löschen", "fr": "Effacer la recherche",
    "id": "Hapus kata kunci", "vi": "Xóa từ khóa tìm kiếm", "tr": "Aramayı temizle", "ru": "Очистить поиск",
    "hi": "खोज मिटाएँ", "th": "ล้างคำค้นหา", "pt-BR": "Limpar busca", "es-ES": "Borrar búsqueda", "es-419": "Borrar búsqueda",
    "zh-Hans": "清除搜索内容", "zh-Hant-TW": "清除搜尋內容", "zh-Hant-HK": "清除搜尋內容"}

# Search result: %1$@ date, %2$@ kind, %3$@ value.
T["%@, %@ %@"] = {l: "%1$@, %2$@, %3$@" for l in LANGS}
T["%@, %@ %@"].update({"ja": "%1$@、%2$@、%3$@", "zh-Hans": "%1$@，%2$@，%3$@", "zh-Hant-TW": "%1$@，%2$@，%3$@",
                       "zh-Hant-HK": "%1$@，%2$@，%3$@", "th": "%1$@ %2$@ %3$@"})
# Date card: %1$@ date, %2$@ the day's values.
T["%@, %@"] = {l: "%1$@, %2$@" for l in LANGS}
T["%@, %@"].update({"ja": "%1$@、%2$@", "zh-Hans": "%1$@，%2$@", "zh-Hant-TW": "%1$@，%2$@", "zh-Hant-HK": "%1$@，%2$@",
                    "th": "%1$@ %2$@"})

T["뒤로"] = {
    "en": "Back", "ja": "戻る", "de": "Zurück", "fr": "Retour", "id": "Kembali", "vi": "Quay lại", "tr": "Geri",
    "ru": "Назад", "hi": "वापस", "th": "ย้อนกลับ", "pt-BR": "Voltar", "es-ES": "Atrás", "es-419": "Atrás",
    "zh-Hans": "返回", "zh-Hant-TW": "返回", "zh-Hant-HK": "返回"}

T["저장하지 못했어요"] = {
    "en": "Couldn’t save", "ja": "保存できませんでした", "de": "Speichern fehlgeschlagen", "fr": "Impossible d’enregistrer",
    "id": "Tidak dapat menyimpan", "vi": "Không lưu được", "tr": "Kaydedilemedi", "ru": "Не удалось сохранить",
    "hi": "सहेजा नहीं जा सका", "th": "บันทึกไม่สำเร็จ", "pt-BR": "Não foi possível salvar",
    "es-ES": "No se ha podido guardar", "es-419": "No se pudo guardar", "zh-Hans": "无法保存",
    "zh-Hant-TW": "無法儲存", "zh-Hant-HK": "無法儲存"}

# Confirmation button: delete every item of the day (%lld items).
T["이날 기록 %lld개 삭제"] = {
    "en": P("Delete %lld item from this day", "Delete %lld items from this day"),
    "ja": "この日の記録%lld件を削除",
    "de": P("%lld Element dieses Tages löschen", "%lld Elemente dieses Tages löschen"),
    "fr": P("Supprimer %lld élément de ce jour", "Supprimer %lld éléments de ce jour", many="Supprimer %lld éléments de ce jour"),
    "id": "Hapus %lld item pada tanggal ini",
    "vi": "Xóa %lld mục của ngày này",
    "tr": "Bu günün %lld öğesini sil",
    "ru": P("Удалить %lld элемент за этот день", "Удалить %lld элемента за этот день",
            few="Удалить %lld элемента за этот день", many="Удалить %lld элементов за этот день"),
    "hi": "इस दिन के %lld आइटम मिटाएँ",
    "th": "ลบ %lld รายการของวันที่เลือก",
    "pt-BR": P("Excluir %lld item deste dia", "Excluir %lld itens deste dia", many="Excluir %lld itens deste dia"),
    "es-ES": P("Eliminar %lld elemento de este día", "Eliminar %lld elementos de este día", many="Eliminar %lld elementos de este día"),
    "es-419": P("Eliminar %lld elemento de este día", "Eliminar %lld elementos de este día", many="Eliminar %lld elementos de este día"),
    "zh-Hans": "删除当天的 %lld 项记录",
    "zh-Hant-TW": "刪除這天的 %lld 個項目",
    "zh-Hant-HK": "刪除當天的 %lld 個項目"}

T["이날 기록 %lld개를 삭제했어요."] = {
    "en": P("Deleted %lld item from this day.", "Deleted %lld items from this day."),
    "ja": "この日の記録%lld件を削除しました。",
    "de": P("%lld Element dieses Tages gelöscht.", "%lld Elemente dieses Tages gelöscht."),
    "fr": P("%lld élément de ce jour supprimé.", "%lld éléments de ce jour supprimés.", many="%lld éléments de ce jour supprimés."),
    "id": "%lld item pada tanggal ini sudah dihapus.",
    "vi": "Đã xóa %lld mục của ngày này.",
    "tr": "Bu günün %lld öğesi silindi.",
    "ru": P("Удалён %lld элемент за этот день.", "Удалено %lld элемента за этот день.",
            few="Удалено %lld элемента за этот день.", many="Удалено %lld элементов за этот день."),
    "hi": "इस दिन के %lld आइटम मिटा दिए गए।",
    "th": "ลบ %lld รายการของวันที่เลือกแล้ว",
    "pt-BR": P("%lld item deste dia foi excluído.", "%lld itens deste dia foram excluídos.", many="%lld itens deste dia foram excluídos."),
    "es-ES": P("Se ha eliminado %lld elemento de este día.", "Se han eliminado %lld elementos de este día.", many="Se han eliminado %lld elementos de este día."),
    "es-419": P("Se eliminó %lld elemento de este día.", "Se eliminaron %lld elementos de este día.", many="Se eliminaron %lld elementos de este día."),
    "zh-Hans": "已删除当天的 %lld 项记录。",
    "zh-Hant-TW": "已刪除這天的 %lld 個項目。",
    "zh-Hant-HK": "已刪除當天的 %lld 個項目。"}

T["확인"] = {
    "en": "OK", "ja": "OK", "de": "OK", "fr": "OK", "id": "OK", "vi": "OK", "tr": "Tamam", "ru": "ОК", "hi": "ठीक है",
    "th": "ตกลง", "pt-BR": "OK", "es-ES": "Aceptar", "es-419": "Aceptar", "zh-Hans": "好", "zh-Hant-TW": "好",
    "zh-Hant-HK": "好"}

T["저장 공간을 확인한 뒤 다시 시도해 주세요."] = {
    "en": "Check your storage and try again.", "ja": "ストレージの空き容量を確認して、もう一度お試しください。",
    "de": "Prüfe den Speicherplatz und versuche es erneut.", "fr": "Vérifiez l’espace de stockage, puis réessayez.",
    "id": "Periksa ruang penyimpanan, lalu coba lagi.", "vi": "Hãy kiểm tra dung lượng lưu trữ rồi thử lại.",
    "tr": "Depolama alanını kontrol edip tekrar dene.", "ru": "Проверьте свободное место и попробуйте ещё раз.",
    "hi": "स्टोरेज जाँचकर फिर से कोशिश करें।", "th": "โปรดตรวจสอบพื้นที่เก็บข้อมูลแล้วลองอีกครั้ง",
    "pt-BR": "Verifique o armazenamento e tente de novo.", "es-ES": "Revisa el almacenamiento e inténtalo de nuevo.",
    "es-419": "Revisa el almacenamiento y vuelve a intentarlo.", "zh-Hans": "请检查存储空间后重试。",
    "zh-Hant-TW": "請檢查儲存空間後再試一次。", "zh-Hant-HK": "請檢查儲存空間後再試一次。"}

T["아직 남긴 기록이 없어요."] = {
    "en": "No notes yet.", "ja": "まだ記録がありません。", "de": "Noch keine Notizen.", "fr": "Aucune note pour l’instant.",
    "id": "Belum ada catatan.", "vi": "Chưa có ghi chú nào.", "tr": "Henüz not yok.", "ru": "Записей пока нет.",
    "hi": "अभी कोई नोट नहीं है।", "th": "ยังไม่มีบันทึก", "pt-BR": "Nenhuma anotação ainda.", "es-ES": "Aún no hay notas.",
    "es-419": "Aún no hay notas.", "zh-Hans": "还没有记录。", "zh-Hant-TW": "還沒有紀錄。", "zh-Hant-HK": "未有記錄。"}

T["첫 기록 남기기"] = {
    "en": "Write your first note", "ja": "最初の記録を残す", "de": "Erste Notiz schreiben", "fr": "Écrire ma première note",
    "id": "Tulis catatan pertama", "vi": "Viết ghi chú đầu tiên", "tr": "İlk notunu yaz", "ru": "Сделать первую запись",
    "hi": "पहला नोट लिखें", "th": "เขียนบันทึกแรก", "pt-BR": "Escrever a primeira anotação", "es-ES": "Escribir la primera nota",
    "es-419": "Escribir la primera nota", "zh-Hans": "写下第一条记录", "zh-Hant-TW": "寫下第一筆紀錄", "zh-Hant-HK": "寫下第一則記錄"}

# Card date: %1$lld day number, %2$@ short weekday (Figma 289-16838: "26 / 목", "Thu 26", "10 / 火").
T["%lld / %@"] = {l: "%2$@ %1$lld" for l in LANGS}
T["%lld / %@"].update({"ja": "%1$lld / %2$@", "zh-Hans": "%1$lld / %2$@", "zh-Hant-TW": "%1$lld / %2$@",
                       "zh-Hant-HK": "%1$lld / %2$@", "vi": "%2$@ %1$lld", "hi": "%2$@ %1$lld"})

T["월 선택"] = {
    "en": "Choose month", "ja": "月を選択", "de": "Monat wählen", "fr": "Choisir le mois", "id": "Pilih bulan",
    "vi": "Chọn tháng", "tr": "Ay seç", "ru": "Выбор месяца", "hi": "महीना चुनें", "th": "เลือกเดือน",
    "pt-BR": "Escolher mês", "es-ES": "Elegir mes", "es-419": "Elegir mes", "zh-Hans": "选择月份",
    "zh-Hant-TW": "選擇月份", "zh-Hant-HK": "選擇月份"}

T["다음 날"] = {
    "en": "Next day", "ja": "翌日", "de": "Nächster Tag", "fr": "Jour suivant", "id": "Hari berikutnya", "vi": "Ngày tiếp theo",
    "tr": "Sonraki gün", "ru": "Следующий день", "hi": "अगला दिन", "th": "วันถัดไป", "pt-BR": "Próximo dia",
    "es-ES": "Día siguiente", "es-419": "Día siguiente", "zh-Hans": "下一天", "zh-Hant-TW": "下一天", "zh-Hant-HK": "下一日"}
T["이전 날"] = {
    "en": "Previous day", "ja": "前日", "de": "Vorheriger Tag", "fr": "Jour précédent", "id": "Hari sebelumnya",
    "vi": "Ngày trước", "tr": "Önceki gün", "ru": "Предыдущий день", "hi": "पिछला दिन", "th": "วันก่อนหน้า",
    "pt-BR": "Dia anterior", "es-ES": "Día anterior", "es-419": "Día anterior", "zh-Hans": "上一天",
    "zh-Hant-TW": "上一天", "zh-Hant-HK": "上一日"}

T["쓰면서 떠오른 생각이 있나요?\n어떤 이야기든 반가워요."] = {
    "en": "Thought of something while writing?\nWe’d love to hear anything.",
    "ja": "記録しながら思いついたことはありますか？\nどんなことでも大歓迎です。",
    "de": "Ist dir beim Schreiben etwas eingefallen?\nWir freuen uns über jede Nachricht.",
    "fr": "Une idée vous est venue en écrivant ?\nNous serons ravis de vous lire.",
    "id": "Ada yang terpikir saat menulis?\nCerita apa pun kami sambut.",
    "vi": "Bạn có suy nghĩ gì khi ghi chép không?\nChúng tôi luôn vui khi được nghe.",
    "tr": "Yazarken aklına bir şey geldi mi?\nHer türlü mesaja açığız.",
    "ru": "Появилась мысль, пока писали?\nБудем рады любому сообщению.",
    "hi": "लिखते समय कोई विचार आया?\nहम कुछ भी सुनना चाहेंगे।",
    "th": "มีความคิดอะไรเกิดขึ้นระหว่างเขียนไหม\nเรายินดีรับฟังทุกเรื่อง",
    "pt-BR": "Pensou em algo enquanto escrevia?\nQueremos ouvir o que for.",
    "es-ES": "¿Se te ha ocurrido algo mientras escribías?\nNos encantará leerte.",
    "es-419": "¿Se te ocurrió algo mientras escribías?\nNos encantará leerte.",
    "zh-Hans": "写的时候有想到什么吗？\n什么都欢迎告诉我们。",
    "zh-Hant-TW": "寫的時候有想到什麼嗎？\n任何想法都歡迎告訴我們。",
    "zh-Hant-HK": "寫的時候有想到甚麼嗎？\n任何想法都歡迎告訴我們。"}

T["주소를 복사했어요"] = {
    "en": "Address copied", "ja": "アドレスをコピーしました", "de": "Adresse kopiert", "fr": "Adresse copiée",
    "id": "Alamat disalin", "vi": "Đã sao chép địa chỉ", "tr": "Adres kopyalandı", "ru": "Адрес скопирован",
    "hi": "पता कॉपी हो गया", "th": "คัดลอกที่อยู่แล้ว", "pt-BR": "Endereço copiado", "es-ES": "Dirección copiada",
    "es-419": "Dirección copiada", "zh-Hans": "已复制地址", "zh-Hant-TW": "已拷貝地址", "zh-Hant-HK": "已複製地址"}
T["주소 복사"] = {
    "en": "Copy address", "ja": "アドレスをコピー", "de": "Adresse kopieren", "fr": "Copier l’adresse",
    "id": "Salin alamat", "vi": "Sao chép địa chỉ", "tr": "Adresi kopyala", "ru": "Скопировать адрес",
    "hi": "पता कॉपी करें", "th": "คัดลอกที่อยู่", "pt-BR": "Copiar endereço", "es-ES": "Copiar dirección",
    "es-419": "Copiar dirección", "zh-Hans": "复制地址", "zh-Hant-TW": "拷貝地址", "zh-Hant-HK": "複製地址"}
T["메일로 보내기"] = {
    "en": "Send email", "ja": "メールで送る", "de": "Per E-Mail senden", "fr": "Envoyer un e-mail",
    "id": "Kirim email", "vi": "Gửi email", "tr": "E-posta gönder", "ru": "Написать письмо",
    "hi": "ईमेल भेजें", "th": "ส่งอีเมล", "pt-BR": "Enviar e-mail", "es-ES": "Enviar correo",
    "es-419": "Enviar correo", "zh-Hans": "发送邮件", "zh-Hant-TW": "傳送郵件", "zh-Hant-HK": "傳送電郵"}
T["메일 앱을 열 수 없어요. 아래 주소로 보내주세요."] = {
    "en": "Can’t open a mail app. Please write to the address below.",
    "ja": "メールアプリを開けません。下のアドレスに送ってください。",
    "de": "Keine Mail-App verfügbar. Schreib uns bitte an die Adresse unten.",
    "fr": "Impossible d’ouvrir une app de messagerie. Écrivez à l’adresse ci-dessous.",
    "id": "Aplikasi email tidak dapat dibuka. Kirim ke alamat di bawah.",
    "vi": "Không mở được ứng dụng email. Hãy gửi đến địa chỉ bên dưới.",
    "tr": "E-posta uygulaması açılamıyor. Lütfen aşağıdaki adrese yaz.",
    "ru": "Не удаётся открыть почтовое приложение. Напишите на адрес ниже.",
    "hi": "ईमेल ऐप नहीं खुल सका। नीचे दिए पते पर भेजें।",
    "th": "เปิดแอปอีเมลไม่ได้ โปรดส่งไปยังที่อยู่ด้านล่าง",
    "pt-BR": "Não foi possível abrir um app de e-mail. Escreva para o endereço abaixo.",
    "es-ES": "No se puede abrir una app de correo. Escribe a la dirección de abajo.",
    "es-419": "No se puede abrir una app de correo. Escribe a la dirección de abajo.",
    "zh-Hans": "无法打开邮件应用，请发送到下方地址。",
    "zh-Hant-TW": "無法開啟郵件 App，請寄到下方地址。",
    "zh-Hant-HK": "無法開啟電郵 App，請寄到下方地址。"}

T["연도 %@"] = {
    "en": "Year %@", "ja": "年 %@", "de": "Jahr %@", "fr": "Année %@", "id": "Tahun %@", "vi": "Năm %@", "tr": "Yıl %@",
    "ru": "Год %@", "hi": "वर्ष %@", "th": "ปี %@", "pt-BR": "Ano %@", "es-ES": "Año %@", "es-419": "Año %@",
    "zh-Hans": "年份 %@", "zh-Hant-TW": "年份 %@", "zh-Hant-HK": "年份 %@"}
T["두 번 탭해 골라요."] = {
    "en": "Double-tap to choose.", "ja": "ダブルタップで選択します。", "de": "Doppeltippen zum Auswählen.",
    "fr": "Touchez deux fois pour choisir.", "id": "Ketuk dua kali untuk memilih.", "vi": "Chạm hai lần để chọn.",
    "tr": "Seçmek için iki kez dokun.", "ru": "Коснитесь дважды, чтобы выбрать.", "hi": "चुनने के लिए दो बार टैप करें।",
    "th": "แตะสองครั้งเพื่อเลือก", "pt-BR": "Toque duas vezes para escolher.", "es-ES": "Toca dos veces para elegir.",
    "es-419": "Toca dos veces para elegir.", "zh-Hans": "轻点两下即可选择。", "zh-Hant-TW": "點兩下即可選擇。",
    "zh-Hant-HK": "點兩下即可選擇。"}
