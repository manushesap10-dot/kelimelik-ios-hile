# GitHub'a yükle + Codemagic ile IPA

Proje klasörü:
`C:\Users\Casper\Desktop\kelimelikporje\ios_rebuild\kelimelik_ios_hile`

---

## A) GitHub'a yükleme (Windows)

### 1) GitHub'da boş repo aç
1. https://github.com/new
2. Repository name: örn. `kelimelik-ios-hile`
3. **Public** veya Private
4. README / .gitignore **EKLEME** (bizde var)
5. **Create repository**

### 2) PowerShell — bu komutları sırayla çalıştır

```powershell
cd C:\Users\Casper\Desktop\kelimelikporje\ios_rebuild\kelimelik_ios_hile

git init
git add .
git status
git commit -m "Initial Kelimelik iOS HILE Flutter project"
git branch -M main

# AŞAĞIDAKİ URL'Yİ KENDİ REPO'NLA DEĞİŞTİR:
git remote add origin https://github.com/KULLANICI_ADIN/kelimelik-ios-hile.git

git push -u origin main
```

GitHub kullanıcı/şifre isterse:
- Şifre yerine **Personal Access Token** kullan
- GitHub → Settings → Developer settings → Personal access tokens

### 3) Kontrol
Tarayıcıda repo sayfanda `lib/`, `pubspec.yaml`, `assets/` görünmeli.

---

## B) Codemagic bağlama

1. https://codemagic.io → GitHub ile giriş
2. **Add application** → bu repoyu seç
3. Project type: **Flutter**
4. Workflow: repodaki `codemagic.yaml` kullanılır (veya UI wizard)
5. **iOS code signing**:
   - Apple Developer hesabın varsa: certificate + profile yükle
   - Yoksa: önce imzasız build dener; sideload için yine imza gerekir
6. **Start new build**
7. Bitince Artifacts → `.ipa` indir

---

## C) Codemagic'de sık takılan yerler

| Sorun | Çözüm |
|--------|--------|
| `ios/Runner.xcodeproj` yok | `codemagic.yaml` içinde `flutter create --platforms=ios .` var |
| Signing error | Codemagic → Teams → code signing identities |
| Bundle ID | `com.example.kelimelikIosHile` veya kendi ID'n |
| Pod error | `pod install` script adımı |

---

## D) Telefona kurma

- **Sideloadly** (Windows) veya **AltStore**
- Ücretsiz Apple ID ile genelde 7 günde bir yenileme

---

## Önemli

- Sadece `kelimelik_ios_hile` klasörünü yükle (tüm `kelimelikporje` değil).
- APK / BlueStacks dosyalarını GitHub'a koyma (gerek yok, repo şişer).
