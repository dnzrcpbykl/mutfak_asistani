# Mutfak Asistanı  

**Türkiye’nin ilk gerçek yapay zeka destekli mutfak asistanı**  
Buzdolabındaki malzemeleri söyle ya da market fişini okut, gerisini bize bırak. Akıllı tarif önerileri, fiyat karşılaştırması, alışveriş listesi ve aileyle paylaşım — hepsi tek uygulamada.

<a href="https://github.com/dnzrcpbykl/mutfak_asistani">
  <img src="assets/splash.png" width="100%" alt="Mutfak Asistanı Splash" />
</a>

## Özellikler

| Özellik                              | Açıklama                                                                                 |
|--------------------------------------|------------------------------------------------------------------------------------------|
| **Fiş & Barkod Okuma**               | Market fişini kamerayla tarat → malzemeler otomatik eklensin!                           |
| **Buzdolabı Envanteri**              | Evde hangi malzemeler var? Hangi tarihte bitiyor? Hepsini takip et.                     |
| **AI Tarif Önerisi (Gemini)**        | Elindeki malzemelere + hava durumuna göre en uygun tarifleri anında öneriyoruz.          |
| **Market Fiyat Karşılaştırması**     | Migros, A101, Şok, Bim… En ucuz nereden alınır? Gösteriyoruz.                            |
| **Akıllı Alışveriş Listesi**         | Eksik malzemeler otomatik listeye eklenir, markete göre sıralanır.                      |
| **Aile / Ev Paylaşımı**              | Aynı evdeki herkes aynı buzdolabını ve listeyi görür, gerçek zamanlı güncellenir.       |
| **Tarif PDF & Yazdır**               | Beğendiğin tarifi PDF yap ya da direkt yazdır.                                           |
| **Premium & Reklam Destekli**        | Temel özellikler ücretsiz, reklamsız deneyim ve gelişmiş özellikler için Premium.       |
| **Karanlık Mod & Modern UI**         | Flutter ile hazırlanmış, akıcı animasyonlar ve göz yormayan tasarım.                    |

## Ekran Görüntüleri

<img src="screenshots/1.png" width="32%" /> <img src="screenshots/2.png" width="32%" /> <img src="screenshots/3.png" width="32%" />

*(Daha fazla ekran görüntüsü yakında eklenecek)*

## Teknolojiler

- **Flutter** – Tek kodla iOS, Android, Web, Windows, macOS, Linux  
- **Firebase** – Auth, Firestore, Cloud Functions  
- **Google Gemini API** – Yapay zeka tarif önerileri  
- **Google ML Kit** – Fiş ve metin tanıma (OCR)  
- **Google Mobile Ads** – Monetizasyon  
- **Provider** – State management  

## Kurulum & Geliştirme

```bash
# Repo'yu klonla
git clone https://github.com/dnzrcpbykl/mutfak_asistani.git
cd mutfak_asistani

# Bağımlılıkları yükle
flutter pub get

# .env dosyasını oluştur (örnek: .env.example var ise)
cp .env.example .env
# Firebase, Gemini ve AdMob anahtarlarını ekle

# Çalıştır
flutter run
