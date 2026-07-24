# Android → iOS RE Özeti

## Motor
- Android: Flutter (`libflutter.so` + `libapp.so`)
- Oyun ağı: özel TCP (TLS değil), `GameModule_*` mesajları

## Çıkarılanlar
1. **Assetler**: 822 image, sounds, fonts, wordlist
2. **Protokol**:
   - login / deviceInfo / gameInfo / submitLetters
   - submit body: `gameId, word, row, col, dir`
3. **HILE akışı** (çalışan Android portable):
   - tahta+rack yakala
   - TR solver
   - tek submit, başarıda dur
   - oyun-başına kilit

## iOS yeniden inşa
`kelimelik_ios_hile` Flutter projesi aynı protokol + solver + HILE UI içerir.
IPA için Mac + Xcode + `flutter build ipa` gerekir.

## Sınırlar
- Tam orijinal UI/animasyon/mağaza birebir klon değildir.
- Sunucu tarafı hesap/PID bilgini sen girersin.
- FairPlay’li App Store IPA kırma yok; bu proje bağımsız yeniden yazımdır.
