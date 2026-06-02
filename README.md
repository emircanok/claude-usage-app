# Claude Usage

macOS menü çubuğunda **Claude Code kullanım yüzdesini** canlı gösteren küçük, native bir uygulama. Menü çubuğunda 5 saatlik limitin yüzdesi renk kodlu görünür; tıklayınca 5 saatlik / haftalık limitler, model bazlı kullanım ve sıfırlanma geri sayımları açılır.

> Swift + SwiftUI (`MenuBarExtra`), App Sandbox yok, Dock ikonu yok — sade bir menü çubuğu ajanı.

## Özellikler

- 🎯 Menü çubuğunda 5 saatlik kullanım yüzdesi (renk kodlu: yeşil → turuncu → kırmızı)
- 📊 Popover'da 5 saatlik + haftalık + Sonnet/Opus kullanımı ve sıfırlanma geri sayımları
- 🔔 %75 ve %90 eşiklerinde tek seferlik macOS bildirimi
- 🚀 Açılışta otomatik başlatma (Login Items / `SMAppService`)
- 🔄 5 dakikada bir + popover açılışında + manuel yenileme

## Nasıl çalışır?

OAuth token'ı macOS Keychain'den (`Claude Code-credentials`) okur ve Claude Code'un `/usage` komutuyla aynı resmî endpoint'i (`api.anthropic.com/api/oauth/usage`) çağırır.

Token'ın süresi dolmak üzereyse, Claude Code ile **birebir aynı şekilde** tazeler (`claude.ai/v1/oauth/token`) ve yeni token'ı Keychain'deki aynı kayda yerinde yazar — böylece Claude Code çalışmaya devam eder ve iki taraf senkron kalır. Token hiçbir üçüncü tarafa gönderilmez; yalnızca Anthropic'in resmî uçları kullanılır.

## Gereksinimler

- macOS 14+
- Giriş yapılmış Claude Code (token'ın Keychain'de olması için)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) + Xcode 15+

## Derleme & çalıştırma

```bash
xcodegen generate
xcodebuild -project ClaudeUsage.xcodeproj -scheme ClaudeUsage \
  -configuration Release -derivedDataPath build clean build
open build/Build/Products/Release/ClaudeUsage.app
```

İlk açılışta macOS bir Keychain erişim izni soracak → **"Her Zaman İzin Ver"** seç.

Açılışta-başlat özelliğinin kararlı çalışması için uygulamayı `/Applications`'a taşı:

```bash
cp -R build/Build/Products/Release/ClaudeUsage.app /Applications/
```

> `project.yml` değiştirdiğinde ya da kaynak dosyası ekleyip çıkardığında `xcodegen generate` komutunu tekrar çalıştır — `.xcodeproj` bu dosyadan üretilir, elle düzenlenmez.

## Proje yapısı

```
ClaudeUsage/
├── ClaudeUsageApp.swift     # @main, AppDelegate, MenuBarExtra
├── UsageViewModel.swift      # @Observable @MainActor — tek doğruluk kaynağı, 5 dk polling
├── KeychainReader.swift      # Keychain okuma + token yerinde güncelleme (SecItemUpdate)
├── TokenRefresher.swift      # OAuth token tazeleme
├── UsageClient.swift         # Usage endpoint isteği
├── Models.swift              # Decodable modeller + tarih çözümleme
├── PopoverView.swift         # Açılır panel UI
├── LabelRenderer.swift       # Renkli menü çubuğu etiketi (NSImage)
├── NotificationManager.swift # Eşik bildirimleri
└── LaunchAtLogin.swift       # SMAppService entegrasyonu
```

## Mimari notlar

- **App Sandbox yok.** Sandbox'lı bir uygulama başka bir uygulamanın (Claude Code'un) Keychain kaydını okuyamaz; bu da uygulamanın tüm işlevini bozar. `project.yml` bilinçli olarak entitlements içermez.
- **Renkli menü çubuğu etiketi.** `MenuBarExtra` `Text`/SF Symbol'ları monokrom template image olarak çizer. `LabelRenderer` rengi korumak için SwiftUI görünümünü `isTemplate = false` bir `NSImage`'e render eder.
- **`User-Agent` zorunlu.** Usage endpoint'i `claude-code/<sürüm>` user-agent'ı olmadan agresif şekilde rate-limit'li (429) bir bucket döndürür.

## Notlar

- **Token süresi dolarsa** ("Token süresi doldu" mesajı): herhangi bir Claude Code komutu çalıştır, token Keychain'de tazelenir.
- Ad-hoc imza ile her yeniden derlemede Keychain izni tekrar sorulabilir. Sabit bir geliştirici sertifikasıyla imzalarsan bir daha sormaz.

## Sorumluluk reddi

Resmî bir Anthropic ürünü değildir. Claude Code'un kullandığı, resmî olarak belgelenmemiş usage endpoint'ini kullanır; bu uç değişebilir.
