import server


def main() -> None:
    # Ensure DB exists (не обязательно для QR, но безопасно)
    server.init_db()

    # Инициализация Firebase с захардкоженными SMART_BIN_CENTER_ID/FIREBASE_SERVICE_ACCOUNT
    server.init_firebase()

    # Симулируем детекцию банки (можно поменять на "paper")
    label = "can"
    qr = server.create_intake_qr_sync(label)

    if not qr:
        print(f"QR not created for label={label!r} (Firebase отключён или нет материала).")
    else:
        print("QR created:")
        print(f"  id:      {qr['id']}")
        print(f"  payload: {qr['payload']}")
        print(f"  png len: {len(qr['png_base64'])} chars")


if __name__ == "__main__":
    main()

