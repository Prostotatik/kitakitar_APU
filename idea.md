Prosto Tak, [2/3/2026 8:19 PM]
Recycling
Stack:
Frontend:
Flutter
Backend:
Firebase
DB:
Firestore
AI(photo recognition):
Google AI
Add-ons:
Google map

UX:
Клиент(mobile app)
 1. Делает фото мусора.
 2. AI определяет тип материала и примерный объём.
 3. На карте показываются подходящие recycling centers.
 4. Клиент выбирает центр и приезжает туда.
 5. После сдачи мусора сканирует QR-код с экрана менеджера центра.
 6. Получает points и обновлённую статистику.

Центр переработки(website)
 1. Регистрируется и настраивает профиль центра(адрес, принимаемый материалы, принимаемый мин и макс для каждого материала, цена покупки мусора(если free, то клиент получает x1.5 points при сканировании).
 2. Принимает мусор от клиента.
 3. Вводит фактический вес материалов.
 4. Система:
 • сохраняет транзакцию;
 • начисляет points центру и статистику центру;
 • генерирует QR-код для клиента, после сканирования которого, клиенту тоже начисляются points и статистика.

UI:
Клиент(mobile app)
Without auth session:
В центре экрана поле для log in с полями почты и пароля, под ними кнопка войти с помощью Google. Ещё чуть ниже две кликабельные надписи(register, forgot password). В случае register будут поля для Имени, Почты, Пароля, Подтверждения пароля. Ниже зарегистрироваться с Google, ещё ниже надпись login. 

With auth session:
По умолчанию открыта секция Scan.

Главный экран(по умолчанию секция Scan):
Bottom Navigation Bar(Scan, Map, Leaders, Profile)

Секция Scan:
Весь бэкграунд это не интерактивный визуал, если тапнуть в любом месте, то откроет камеру, сделаный снимок отправит в Google AI, затем выведет результат и предложит перейти к карте, при переходе к карте по кнопке, автоматически применяются фильтры и показывает на карте подходящие центры переработки, а так же снизу вылезет окно с Recommend Center(рассчитывается из фильтров + расстояние + его количество points)

Секция Map:
Google Map с фильтрацией по Принимаемым материалам, Мин и макс принимаемому весу материалов

Секция Leaders:
Свайп в лево/вправо чтобы переключаться между Лидербордами пользователей и центров переработки по points, total weight и тд.

Секция Profile:
Возможность аватар, имя, почту, пароль.

Центр переработки(website)
Without auth session:
В центре экрана поле для log in с полями почты и пароля. Ещё чуть ниже две кликабельные надписи(register, forgot password). В случае register будут поля для Названия центра, адреса центра, Принимаемых материалов, принимаемый вес для каждого материала, цена скупки каждого материала(возможна опция free, то есть клиент не получает денег а сдаёт бесплатно) Имени менеджера, телефона менеджера, Почты, Пароля, Подтверждения пароля, ниже надпись login. 

With auth session:
Админ панель для изменения данных центра переработки, мониторинга статистики. Кнопка для внесения данных о приёме нового мусора, которая так же генерирует QR код, затем Клиент может просканировать этот QR для получения очков и статистики на свой аккаунт. Должна быть возможность смотреть старые коды, историю приёмки, qr должен работать только до первого использования клиентом.


🗂️ Общая структура Firestore

/users
/centers
/materials
/transactions
/qr_codes
/leaderboards (опционально, кэш)
/ai_scans

👤 Users (клиенты, mobile app)

/users/{userId}

{
  "name": "Alex",
  "email": "alex@mail.com",
  "avatarUrl": "https://...",
  "points": 1240,
  "totalWeight": 87.5,
  "createdAt": Timestamp,
  "lastLoginAt": Timestamp,
  "provider": "email | google",
  "stats": {
    "plastic": 32.1,
    "glass": 20.4,
    "paper": 35.0
  }
}
🔹 Зачем stats объект?
Чтобы быстро показывать профиль и лидерборды без агрегаций.

🏭 Recycling Centers

/centers/{centerId}

{
  "name": "Green Recycle",
  "address": "Tashkent, ...",
  "location": {
    "lat": 41.2995,
    "lng": 69.2401
  },
  "manager": {
    "name": "Ivan",
    "phone": "+998901234567",
    "email": "manager@center.com"
  },
  "points": 5420,
  "totalWeight": 1340.8,
  "createdAt": Timestamp,
  "isActive": true
}
📦 Материалы, принимаемые центром (subcollection)

/centers/{centerId}/materials/{materialId}

{
  "type": "plastic",
  "minWeight": 0.5,

Prosto Tak, [2/3/2026 8:19 PM]
"maxWeight": 50,
  "pricePerKg": 1200,
  "isFree": false
}
📌 Почему subcollection, а не массив?
Фильтрация
Обновление одного материала
Firestore limits (array ≠ scalable)

♻️ Materials (справочник)

какие нужны материалы
Paper/Cardboard
Plastics
Glass
Aluminum
Batteries
Electronics
Food
Lawn Materials
Used Oil
Household Hazardous Waste
Tires
Metal

/materials/{materialId}

{
  "type": "plastic",
  "label": "Plastic",
  "icon": "plastic.png"
}
Используется:
AI
фильтры
UI

🤖 AI Scans (результат распознавания)

/ai_scans/{scanId}

{
  "userId": "uid123",
  "imageUrl": "gs://...",
  "detectedMaterials": [
    {
      "type": "plastic",
      "estimatedWeight": 1.4,
      "confidence": 0.92
    }
  ],
  "createdAt": Timestamp
}
⚠️ Можно чистить по TTL, если не нужна история.

🔄 Transactions (факт приёма мусора)

/transactions/{transactionId}

{
  "userId": "uid123",
  "centerId": "center123",
  "materials": [
    {
      "type": "plastic",
      "weight": 1.2,
      "pricePerKg": 1200,
      "isFree": false
    }
  ],
  "totalWeight": 1.2,
  "pointsUser": 120,
  "pointsCenter": 120,
  "createdAt": Timestamp,
  "qrCodeId": "qr123"
}
📌 Это сердце системы
статистика
лидерборды
аналитика

🔳 QR Codes (одноразовые!)

/qr_codes/{qrId}

{
  "centerId": "center123",
  "transactionDraft": {
    "materials": [
      {
        "type": "plastic",
        "weight": 1.2,
        "isFree": true
      }
    ],
    "totalWeight": 1.2
  },
  "used": false,
  "usedBy": null,
  "createdAt": Timestamp,
  "usedAt": null
}
После сканирования:

{
  "used": true,
  "usedBy": "uid123",
  "usedAt": Timestamp
}
⚠️ Security Rules:
QR можно использовать только 1 раз

🏆 Leaderboards (кэш, не обязательно)

/leaderboards/users
/leaderboards/centers

{
  "type": "users",
  "period": "monthly",
  "items": [
    { "id": "uid1", "points": 1200 },
    { "id": "uid2", "points": 1100 }
  ],
  "updatedAt": Timestamp
}
📌 Обновляется Cloud Function раз в N минут

🧠 Логика начисления points
Обычный приём



points = weight * baseMultiplier


Free приём



points = weight * baseMultiplier * 1.5



🔐 Firebase Auth роли
Тип
Где хранить
user
/users
center
/centers
role
custom claims (role: user / center)
🔥 Cloud Functions (очень рекомендую)
onQrScan()
onTransactionCreate()
updateLeaderboards()
cleanupExpiredQr()