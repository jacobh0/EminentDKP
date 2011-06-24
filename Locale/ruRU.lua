local L = LibStub("AceLocale-3.0"):NewLocale("EminentDKP", "ruRU", false)

if not L then return end

L["EminentDKP: Modes"] = "EminentDKP: Режимы"
L["EminentDKP: %s Items"] = "EminentDKP: %s вещей"

L["Earnings & Deductions"] = "Начисления и штрафы"
L["'s Earnings & Deductions"] = "- Начисления и штрафы"
L["Items Won"] = "Выигранные предметы"
L["Items won by"] = "Предмет выиграл"
L["Auction Winners"] = "Победтиели аукционов"
L["'s Auctions"] = "Аукцион"
L["Awardees"] = "Награжденные"
L["Events missed by"] = "Пропущенные события"

L["All Classes"] = "Все классы"
L["Death Knight"] = "Рыцарь смерти"
L["Druid"] = "Друид"
L["Hunter"] = "Охотник"
L["Mage"] = "Маг"
L["Paladin"] = "Паладин"
L["Priest"] = "Жрец"
L["Rogue"] = "Разбойник"
L["Shaman"] = "Шаман"
L["Warlock"] = "Чернокнижник"
L["Warrior"] = "Воин"
L["Conqueror"] = "Токен: Завоеватель"
L["Vanquisher"] = "Токен: Покоритель"
L["Protector"] = "Токен: Защитник"
L["Cloth"] = "Ткань"
L["Leather"] = "Кожа"
L["Mail"] = "Кольчуга"
L["Plate"] = "Латы"
L["Auctions"] = "Аукционы"
L["Bounties"] = "Награды"
L["Activity"] = "Активность"
L["Vanity"] = "Vanity"
L["Vanity Rolls"] = "Vanity Rolls"
L["Transfers"] = "Переводы"
L["Attendance"] = "Посещяемость"
L["Missed Events"] = "Пропущенные события"

-- Mode columns
L["Percent"] = "Процентов"
L["DKP"] = "ДКП"
L["Source"] = "Источник"
L["Count"] = "Количество"
L["Winner"] = "Победитель"
L["Time"] = "Время"
L["Date"] = "Дата"

L["Monday"] = "Понедельник"
L["Tuesday"] = "Вторник"
L["Wednesday"] = "Среда"
L["Thursday"] = "Четверг"
L["Friday"] = "Пятница"
L["Saturday"] = "Суббота"
L["Sunday"] = "Воскресенье"

L["Manual"] = "Вручную"
L["Automatic"] = "Автоматически"

-- Options

L["Decay Options"] = "Настройки списания"
L["Schedule"] = "Расписание"
L["Select which days of the week a decay will be performed on."] = "Выберете дни недели по которым будет проводится списание."
L["The percentage of DKP that will decay from each player."] = "Проценд ДКП который будет списан с каждого игрока."
L["Rename window"] = "Переименовать окно"
L["Enter the name for the window."] = "Введите название окна."
L["Display system"] = "Display system"
L["Choose the system to be used for displaying data in this window."] = "Choose the system to be used for displaying data in this window."
L["Lock window"] = "Закрепить окно"
L["Locks the bar window in place."] = "Закрпеляет окно на экране."

L["Windows"] = "Окна"
L["Create window"] = "Создать окно"
L["Enter the name for the new window."] = "Введите название нового окна."
L["Delete window"] = "Удалить окно"
L["Choose the window to be deleted."] = "Выберети окно которое необходимо удалить."
L["Delete window"] = "Удалить окно"
L["Deletes the chosen window."] = "Удаляет выбранное окно."

L["General Options"] = "Основные настройки"
L["Hide when solo"] = "Скрывать без группы"
L["Hides EminentDKP's window when not in a party or raid."] = "Скрывает окно EminentDKP, когда игрок без группы или рейда."
L["Hide in Party"] = "Скрывать в группе"
L["Hides EminentDKP's window when in a party."] = "Скрывать окно EminentDKP, когда в группе."
L["Hide in PvP"] = "Скрывать в PvP"
L["Hides EminentDKP's window when in Battlegrounds/Arenas."] = "Скрывать окно EminentDKP на полях боя или аренах."
L["Hide in combat"] = "Скрывать в бою"
L["Hides EminentDKP's window when in combat."] = "Скрывать окно EminentDKP в режиме боя."
L["Number format"] = "Формат чисел"
L["Controls the way large numbers are displayed."] = "Управляет отображением больших чисел"
L["Condensed"] = "Округленно"
L["Detailed"] = "Точно"
L["Show rank numbers"] = "Показывать порядковые номера"
L["Shows numbers for relative ranks for modes where it is applicable."] = "Показывает место игрока в тех режимах, где это возможно."
L["Attendance Period"] = "Период посещяемости"
L["The number of days prior to today to use when measuring attendance."] = "Число дней до текущего для измерения посещяемости."
L["Maximum Mode Events"] = "Максимальное число событий"
L["The maximum number of events to include for certain modes."] = "Максимальное число событий для определенного режима."
L["Maximum Player Events"] = "Максимальное число событий игрока"
L["The maximum number of events to show for a specific player."] = "Максимальное число событий для определенного игрока."
L["Hide Chat Messages"] = "Скрывать сообщения в чате"
L["Prevents chat messages sent by EminentDKP from being shown."] = "Предотвращяет показ сообщений чата EminentDKP."
L["Auction Length"] = "Время аукциона"
L["The number of seconds an auction will run."] = "Число секунд для проведения аукциона."
L["Bid on Enter"] = "Ставка по Enter"
L["Send bid for an auction when pressing enter in the bid amount box."] = "Посылает ставку на аукцион при нажатии клавиши Enter в окне ставки."

L["Officer Options"] = "Офицерские настройки"
L["Disenchanter"] = "Дизэнчантер"
L["The name of the person who will disenchant."] = "Персонаж, которые распылит предмет."
L["Auction Threshold"] = "Порог ценности"
L["The minimum rarity an item must be in order to be auctioned off."] = "Минимальная ценность для предмета, для участия в аукционе."
L["DKP Expiration Time"] = "Срок годности DKP"
L["The number of days after a player's last raid that their DKP expires."] = "Число дней по истечении которых у игрока сгоряет DKP."
L["Guild Group"] = "Гильдиейские группы"
L["Only allow EminentDKP to function inside of a guild group."] = "EminentDKP работает только в гильдейских группах."
L["Disable PVP"] = "Отключить PVP"
L["Do not allow EminentDKP to function during PVP."] = "Не разрешает EminentDKP работать во время PVP."
L["Disable Party"] = "Отключить группы"
L["Do not allow EminentDKP to function in a party."] = "Не разрешает EminentDKP работать в группах."

L["Tooltips"] = "Подсказки"
L["Show tooltips"] = "Показывать подсказки"
L["Shows tooltips with extra information in some modes."] = "Показывает подсказки с дополнительной иноформацией в различных режимах."
L["Informative tooltips"] = "Информативные подсказки"
L["Shows subview summaries in the tooltips."] = "Покзывает итоги в подсказках."
L["Subview rows"] = "Строки итогов"
L["The number of rows from each subview to show when using informative tooltips."] = "Число строк для каждого подрежима информационных подсказок."
L["Tooltip position"] = "Позиция подсказок"
L["Position of the tooltips."] = "Позиция подсказок."
L["Default"] = "По умолчанию"
L["Top right"] = "Сверху справа"
L["Top left"] = "Сверху слева"

L["Window Columns"] = "Строки окна"

L["Title bar"] = "Заголовок"
L["Enables the title bar."] = "Включает заголовок."
L["Background texture"] = "Текстура заднего фоно"
L["The texture used as the background of the title."] = "Текстура для заднего фона заголовка."
L["Border texture"] = "Текстура границы"
L["The texture used for the border of the title."] = "Текстура для границы заголовка."
L["Border thickness"] = "Толщина границы"
L["The thickness of the borders."] = "Толщина границы заголовка."
L["Background color"] = "Цвет заднего фона"
L["The background color of the title."] = "Цвет заднего фона заголовка."
L["Clickthrough"] = "Отключить интерактив"
L["Disables mouse clicks on bars."] = "Отключает щелчки мышью на колонках."
L["Show spark effect"] = "Show spark effect"
L["Bars"] = "Bars"
L["Reverse bar growth"] = "Изменить направление строк"
L["Bars will grow up instead of down."] = "Строки будут расти вверх."
L["Enable Status Bar"] = "Разрешить строку состояния"
L["Enables the the status bar under the title."] = "Разрешает строку состояния под заголовком."

L["The font used by the title bar."] = true
L["Bar font"] = true
L["The font used by all bars."] = true
L["Bar font size"] = true
L["The font size of all bars."] = true
L["The font size of the title bar."] = true
L["Bar texture"] = true
L["The texture used by all bars."] = true
L["Bar spacing"] = true
L["Distance between bars."] = true
L["Bar height"] = true
L["The height of the bars."] = true
L["Bar width"] = true
L["The width of the bars."] = true
L["Bar color"] = true
L["Choose the default color of the bars."] = true
L["Max bars"] = true
L["The maximum number of bars shown."] = true
L["Bar orientation"] = true
L["The direction the bars are drawn in."] = true
L["Left to right"] = true
L["Right to left"] = true

L["The margin between the outer edge and the background texture."] = "The margin between the outer edge and the background texture."
L["Margin"] = "Margin"
L["Window height"] = "Window height"
L["The height of the window. If this is 0 the height is dynamically changed according to how many bars exist."] = "The height of the window. If this is 0 the height is dynamically changed according to how many bars exist."
L["Adds a background frame under the bars. The height of the background frame determines how many bars are shown. This will override the max number of bars setting."] = "Adds a background frame under the bars. The height of the background frame determines how many bars are shown. This will override the max number of bars setting."
L["Adds a background frame under the bars."] = "Adds a background frame under the bars."
L["Enable"] = "Enable"
L["Background"] = "Background"
L["The texture used as the background."] = "The texture used as the background."
L["The texture used for the borders."] = "The texture used for the borders."
L["The color of the background."] = "The color of the background."
L["Alternate color"] = "Alternate color"
L["Choose the alternate color of the bars."] = "Choose the alternate color of the bars."
L["Class color bars"] = "Class color bars"
L["When possible, bars will be colored according to player class."] = "When possible, bars will be colored according to player class."
L["Class color text"] = "Class color text"
L["When possible, bar text will be colored according to player class."] = "When possible, bar text will be colored according to player class."
L["Shows a button for opening the menu in the window title bar."] = "Shows a button for opening the menu in the window title bar."
L["Show menu button"] = "Show menu button"

L["Click for"] = "Клик для"
L["Shift-Click for"] = "Shift-Клик для"
L["Control-Click for"] = "Control-Клик для"

L["Auction Frame"] = "Окно аукциона"

-- Action Panel Confirmations
L["Are you sure you want to transfer %.02f DKP to %s?"] = "Вы уверены, что хотите перечислоить %.02f ДКП игроку %s?"

-- General messages

L["That command must be sent to the master looter."] = "Эта комманда должна быть написана распределителю добычи."
L["The master looter must be an officer."] = "Респределитель добычи должен быть офицером."
L["That command can only be used by an officer."] = "Эта комманд может быть использована только офицером."
L["Master looting must be enabled."] = "Должен быть установлен режим добычи: распределяет ответственный."
L["Only the master looter can use that command."] = "Только распределитель добычи использует данную команду."
L["Your database must be up to date first."] = "Ваша база данных должна быть актуальна."
L["You are not in the current group."] = "Вы не в текущей группе."
L["EminentDKP is currently disabled."] = "EminentDKP на данный момент отключен."

L["Achievement: %s"] = "Достижение: %s"
L["Kill: %s"] = "Убийство: %s"

L["ERROR: %s does not exist in the DKP pool."] = "ОШИБКА: %s не существует в банке ДКП."
L["ERROR: %s is not a fresh player."] = "ОШИБКА: %s не обновленный игрок."
L["ERROR: Invalid bounty amount given."] = "ОШИБКА: Неправильное количество награды."
L["ERROR: Invalid adjustment amount given."] = "ОШИБКА: Неправильное количество начисления."
L["ERROR: An auction must not be active."] = "ОШИБКА: Должен быть аукцион."
L["ERROR: Invalid decay percent given."] = "ОШИБКА: Неправильный процент списания."

L["Successfully renamed %s to %s."] = "Удачно перименован %s в %s."
L["Successfully reset vanity DKP for %s."] = "Удачно обнулен vanity DKP для %s."

L["%s has transferred you"] = "%s перевел вам"
L["%s has transferred %s"] = "%s перевел %s"
L["You have received a bounty of"] = "Вы получили награду"
L["You've won an auction for"] = "Вы выиграли аукцион"
L["You Have Just"] = "Вы Только Что"
L["Won An Auction"] = "Выиграли Аукцион"
L["has been acquired for %d DKP"] = "было получено за %d ДКП"
L["You have been awarded"] = "Вы были награждены"
L["You have been deducted"] = "Вы были оштрафованы"
L["%s has been deducted"] = "%s был оштрафован"
L["%s has been awarded"] = "%s был награжден"
L["Your DKP has decayed by"] = "Ваше ДКП уменшилось на"

L["You must be the master looter to initiate an auction."] = "Вы должны быть распределителем добычи для старта аукциона."
L["You must be looting a corpse to start an auction."] = "Вы должны открыть окно добычи для старта аукциона."
L["An auction is already active."] = "Аукцион уже идет."
L["You cannot transfer DKP during an auction."] = "Вы не можете перечислять ДКП во время аукциона."
L["You cannot transfer DKP to yourself."] = "Вы не можете перечислять ДКП самому себе."
L["You do not exist in the DKP pool."] = "Вас нет в банке ДКП."
L["%s does not exist in the DKP pool."] = "%s не присутствует в банке ДКП."
L["DKP amount must be atleast 1."] = "Должно быть минимум 1 ДКП."
L["The DKP amount must not exceed your current DKP."] = "Ставка не может превышать ваше ДКП."

L["Auction has closed. Determining winner..."] = "Аукцион закрыт. Определяется победитель"
L["No bids received. Disenchanting."] = "Ставок не поступило. Распылить."
L["%s was not eligible to receive loot to disenchant."] = "%s был не доступен для получения добычи для распыления."
L["There is no disenchanter assigned."] = "Не установлен дизэнчантер."
L["A tie was broken with a random roll."] = "Равные ставки, с определением победителя роллом."

L["%s has won %s for %d DKP!"] = "%s выиграл %s за %d ДКП!"
L["No more loot found."] = "Нет больше добычи."

L["A bounty of %.02f has been awarded to %d players."] = "Награда %.02f была распределена среди %d игроков."
L["Each player has received %.02f DKP."] = "Каждый игрок получил %.02f ДКП."
L["The bounty pool is now %.02f DKP."] = "Фонд наград теперь %.02f ДКП."
L["%s has received a deduction of %.02f DKP."] = "%s ДКП было уменьшено на %.02f."
L["%s has been awarded %.02f DKP."] = "%s ДКП было увеличено на %.02f."
-- note: on this one, the %% is just a percent sign, the %.02f is the variable.
L["All active DKP has decayed by %.02f%%."] = "Все активные ДКП были уменьшены на %.02f%%."

L["There is no loot available to auction."] = "Нет доступной добычи для аукциона."
L["There is currently no auction active."] = "Нет текущего аукциона."
L["You are not eligible to receive loot."] = "Добыча вам не подходит."
L["Your bid of %d has been accepted."] = "Ваша ставка %d принята."
L["You cannot utilize this item."] = "Вы не можете одеть данную вещь."
L["Vanity item rolls weighted by current vanity DKP:"] = "Vanity item бросок усилен вашим текущим vanity DKP:"

L["%s has transferred %.02f DKP to %s."] = "%s перечислил %.02f ДКП %s."
L["%s just transferred %.02f DKP to you."] = "%s только что перечислил %.02f ДКП вам."
L["Succesfully transferred %.02f DKP to %s."] = "Успешно перечислено %.02f ДКП к %s."

L["%s now up for auction! Auction ends in %d seconds."] = "%s - АУКЦИОН! Аукцион закончится в течении %d секунд."
L["Bids for %s"] = "Ставки за %s"
L["Tie won by %s (%d)"] = "Равная победа %s (%d)"
L["Won by %s (%d)"] = "Победил %s (%d)"
L["Disenchanted"] = "Распылено"
L["Auction cancelled"] = "Аукцион отменен"
L["Loot from %s:"] = "Добыча - %s:"

L["Current bounty is %.02f DKP."] = "Текущая награла - %.02f ДКП."
L["Auction cancelled. All bids have been voided."] = "Аукцион отменен. Все ставки аннулированы."
L["Current DKP standings:"] = "Текущий список ДКП:"
L["Lifetime Earned DKP standings:"] = "Список ДКП за все время:"

L["Player Report for %s:"] = "Отчет по игроку - %s:"
L["Current DKP:"] = "Текущее ДКП:"
L["Lifetime DKP:"] = "ДКП за все время:"
L["Vanity DKP:"] = "Vanity DKP:"
L["Last Seen: %d day(s) ago."] = "Последний раз в игре: %d дней назад."

L["Available Commands:"] = "Доступные комманды:"
L["Check your current balance"] = "Показывает ваш текущий баланс"
L["Check the current balance of player X"] = "Показывает текущий баланс игрока X"
L["Display the current dkp standings"] = "Показывает текущий список ДКП"
L["Display the lifetime earned dkp standings"] = "Показывает список ДКП за все время"
L["Place a bid of X DKP on the active auction"] = "Поставить ставку X ДКП на текущий аукцион"
L["Transfer X DKP to player Y"] = "Перечислить X ДКП игроку Y"
L["These commands can only be sent to the master looter while in a group"] = "Эти команды могут быть отправленны только распорядителю добычи в группе"
L["Unrecognized command. Whisper %s for a list of valid commands."] = "Нераспознанная комманда. Щепните %s для списка доступных комманд."

L["Performing database scan..."] = "Выполняется сканирование базы данных..."
-- note: on this one, the %% is just a percent sign, the %d is the variable.
L["Performing %d%% decay..."] = "Выполнятеся %d%% списание..."
L["There is more than 50% of the bounty available. You should distribute some."] = "Есть более 50% наград доступных. Вы должны распределить немного."
L["Database has been rebuilt."] = "База данных востановлена."
L["Are you sure you want to reset the database? This cannot be undone."] = "Вы уверены что хотить очистить базу данных? Это невозможно отменить."
L["Database has been reset."] = "База данных была очищена."
L["Please note that it can take up to 5 minutes to record the versions of all other EminentDKP users."] = "Пожалуйста, подождите. Около 5 минут занимает получение версий от других игроков."
L["%s has issued a database reset."] = "%s вызвал очистку базы данных."
L["%s has issued a database reset. Do you wish to comply? This cannot be undone."] = "%s вызвал очистку базы данных. Вы согласны? Это невозможно отменить."
L["Are you sure you want to reset the database for ALL users? This cannot be undone."] = "Вы уверены что хотите очистить базу данных для ВСЕХ пользователей? Это невозможно отменить."
L["Syncing officer options from %s..."] = "Синхронизация настроек офицеров от %s..."

-- Statusbar
L["Syncing..."] = "Синхронизация..."
L["Out of Date"] = "Устаревшие данные"

L["Bounty Pool"] = "Доступные награды"
L["Bounty:"] = "Награды:"
L["Available:"] = "Доступно:"
L["Size:"] = "Размер:"
L["Current:"] = "Текущий:"
L["Newest:"] = "Последний:"
L["Version Info"] = "Версия"
L["Please upgrade to the newest version."] = "Пожалуйста обновитесь до последней версии."

-- Action Panel
L["EminentDKP Action Panel"] = "Панель действий EminentDKP"
L["Vanity"] = "Vanity"
L["Transfer"] = "Перевод"
L["Bounty"] = "Награда"
L["Adjustment"] = "Начисление"

L["Transfer DKP"] = "Перевод ДКП"
L["Recipient"] = "Получатель"
L["Amount"] = "Количество"
L["Send"] = "Отправить"

L["Reset Vanity DKP"] = "Обнулить Vanity DKP"
L["Player"] = "Игрок"
L["Reset"] = "Обнулить"
L["Vanity DKP Roll"] = "Vanity DKP Roll"
L["Roll"] = "Бросок"

L["Rename Player"] = "Переименовать игрока"
L["Rename"] = "Переименовать"
L["New Player"] = "Новый игрок"
L["Old Player"] = "Старый игрок"

L["Award Bounty"] = "Раздать награду"
L["Reason"] = "Причина"
L["Award"] = "Награда"

L["Issue Adjustment"] = "Причина начисления"
L["Deduction"] = "Штраф"
L["Issue"] = "Причина"

L["Versions"] = "Версии"