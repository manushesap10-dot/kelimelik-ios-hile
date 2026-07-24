# Kelimelik iOS HILE — Flutter yeniden inşa (APK → IPA hazırlık)

Bu proje, Android Kelimelik APK’sına yapılan kapsamlı tersine mühendislikten sonra **iOS için sıfırdan yazılmış** Flutter uygulamasıdır.

> **Not:** APK dosyası ikili olarak IPA’ya “dönüştürülmez”. Yapılan şey: asset + protokol + solver + HILE mantığının iOS/Flutter’da yeniden inşasıdır.

## Ne çıkarıldı / taşındı?

| Kaynak (Android RE) | iOS proje |
|---------------------|-----------|
| Özel TCP protokol (login/gameInfo/submit) | `lib/protocol/` |
| En iyi hamle solver + TR puan/premium | `lib/solver/best_move.dart` |
| HILE otomatik oynatma akışı | `lib/services/hile_service.dart` |
| Sözlük (~62k) | `assets/data/wordlist.txt` |
| Oyun görselleri/sesler/fontlar | `assets/images|sounds|fonts` |
| UI (HILE butonu, tahta önizleme) | `lib/ui/home_page.dart` |

## Klasör

```
ios_rebuild/kelimelik_ios_hile/
  lib/
    main.dart
    protocol/codec.dart
    protocol/game_client.dart
    solver/best_move.dart
    services/hile_service.dart
    ui/home_page.dart
  assets/
  ios/          # Xcode/CocoaPods iskeleti
  docs/
  pubspec.yaml
  README.md
```

## Mac’te IPA derleme (zorunlu ortam)

Windows’ta IPA üretilemez. **macOS + Xcode + Flutter** gerekir.

```bash
# 1) Projeyi Mac'e kopyala
cd ios_rebuild/kelimelik_ios_hile

# 2) Flutter iOS platform dosyalarını tamamla (iskelet eksikse)
flutter create --platforms=ios .

# 3) Bağımlılıklar
flutter pub get
cd ios && pod install && cd ..

# 4) İmza: Xcode'da Runner.xcworkspace aç
#    Signing & Capabilities → Team / Bundle ID seç

# 5) IPA
flutter build ipa --release

# Çıktı genelde:
# build/ios/ipa/*.ipa
```

Sideload: **Sideloadly** veya **AltStore** + Apple ID.

## Uygulama kullanımı

1. PID + password hash gir (Android oturumundan RE ile bilinen değerler)
2. **Bağlan + Login**
3. `gameId` doluysa **gameInfo yenile** (veya sunucu push)
4. **HILE OYNAT** → en iyi hamle hesaplanır ve `requestSubmitLetters` gönderilir

### Manuel test (offline solver)
- Rack + 225 char board yapıştır → **Sadece hesapla**

## Güvenlik / yasal
- Bu bir eğitim/RE ödevidir.
- App Store FairPlay kırma **yok**.
- Hesap kimlik bilgilerini paylaşma; kendi test hesabını kullan.

## Android portable APK (referans)

Çalışan taşınabilir Android çıktı:
`yeni_cikti/kelimelik_portable-aligned-debugSigned.apk`

## Sonraki adımlar (isteğe bağlı)
- Tam oyun UI’sini (rakip listesi, animasyonlar) asset’lerle genişletme
- Keychain’de oturum saklama
- Mac CI ile otomatik `flutter build ipa`
