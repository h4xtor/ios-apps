# Philips Remote — iOS

Native SwiftUI-fjernbetjening til Philips-TV med JointSpace API v6 (2016 og
nyere). Port af desktop-appen `PhilipsTVRemote2026`, redesignet fra scratch men
med fuld funktionsparitet.

Alt kører på det lokale netværk. Ingen cloud, ingen konto, ingen telemetri.

---

## Krav

- macOS med **Xcode 15** eller nyere
- **XcodeGen** (`brew install xcodegen`)
- iPhone eller iPad med **iOS 17+**
- TV og telefon på samme subnet

## Byg

```bash
brew install xcodegen
xcodegen generate
open PhilipsRemote.xcodeproj
```

I Xcode: vælg target `PhilipsRemote` → **Signing & Capabilities** → vælg dit team
→ vælg en enhed → **Run**.

Første gang appen starter, beder iOS om adgang til det lokale netværk. Det skal
tillades, ellers kan den ikke nå TV'et.

> **Ingen Mac?** Xcode kræver macOS. Alternativer: en lejet Mac i skyen, eller
> et GitHub Actions-job med `macos-15`-runner der bygger og uploader til
> TestFlight. Windows kan ikke kompilere SwiftUI-apps.

---

## Funktionsparitet

| Desktop-funktion | iOS | Hvor |
|---|---|---|
| Forbind til TV via IP | ✅ | `ConnectView` |
| Parring med PIN (HMAC-SHA1) | ✅ | `ConnectView` → `PhilipsTVClient` |
| Latens-måling | ✅ | header |
| Power on/standby | ✅ | quick row |
| Home, Back, Source, Info | ✅ | quick row |
| D-pad + OK | ✅ | `DPad` |
| Volume op/ned/mute | ✅ | slider + knapper |
| Kanal op/ned | ✅ | kanal-kort |
| Guide | ✅ | kanal-kort |
| Transport (prev/rew/play/fwd/next) | ✅ | transport-række |
| Farvetaster | ✅ | farve-række |
| Ambilight til/fra | ✅ | `AmbilightView` |
| 6 Ambilight-profiler | ✅ | `AmbilightView` |
| Ambilight-telemetri | ✅ | `AmbilightView` |
| App-launcher fra TV'et | ✅ | `AppsView` |
| Kanal-liste + tuning | ✅ | `ChannelsView` |
| Numpad 0–9 | ✅ | `ArsenalView` |
| Kilder: TV + HDMI 1–4 | ✅ | `ArsenalView` |
| Alle 38 JointSpace-taster | ✅ | `ArsenalView` |
| Optagelsesliste | ⚠️ | API-kald findes i `PhilipsTVClient.recordings()`; ingen skærm endnu |
| Tekstindtastning | ⚠️ | afvist af TV'ets capability-report, som i desktop-versionen |

---

## Design

Desktop-versionen var cyberpunk: cyan og magenta på sort, tæt på en terminal.
iOS-versionen vender præmissen: **Ambilight er den eneste lyskilde i rummet.**

- Næsten-sort baggrund (`#07080A`), ingen rammer om alt
- Én accent: `ember` `#FF5A3C`, brugt til det der er levende — OK-knappen,
  volumen, Ambilight
- Sekundære farver bruges kun til farvetasterne, som på en rigtig fjernbetjening
- Runde taster, bløde skygger, `spring`-animation ved tryk, haptik på hver tast
- Typografi: `rounded` til tal og overskrifter, `monospaced` til etiketter
- D-padden er 224 pt med en glødende ring — det er den ene ting fingeren skal
  ramme uden at kigge

Alle skærme deler `ScreenHeader` og `PageScaffold`, så titel, statusprik og
latens sidder samme sted hele vejen rundt.

---

## Arkitektur

```
PhilipsRemote/
├── App.swift                 @main
├── RootView.swift            TabView + fælles header/scaffold
├── Info.plist                ATS, lokal-netværk, dark mode
├── Core/
│   ├── Theme.swift           palette, typografi, knapstyles, haptik
│   ├── Models.swift          domænetyper + hele tastekataloget
│   ├── PhilipsTVClient.swift JointSpace-klient (async/await)
│   ├── DigestAuth.swift      HTTP Digest (MD5) — Philips kræver det
│   ├── Keychain.swift        parringscredentials
│   ├── ConfigStore.swift     IP + validering af privat IPv4
│   └── AppModel.swift        observable state, kommandoer, parring
└── Features/
    ├── ConnectView.swift     IP, parring, PIN
    ├── RemoteView.swift      D-pad, lyd, kanal, transport, farver, genveje
    ├── AppsView.swift        app-launcher med søgning
    ├── ChannelsView.swift    kanalliste med søgning og tuning
    ├── AmbilightView.swift   power, profiler, telemetri
    └── ArsenalView.swift     numpad, kilder, alle taster
```

### Netværkslaget

`PhilipsTVClient` er en tynd async-wrapper:

1. `GET /6/system` over **HTTP:1925** — uautoriseret, bruges til at måle latens
   og læse `api_version.Major`.
2. Alt andet over **HTTPS:1926** med Digest-auth. Philips bruger MD5-digest, så
   headeren bygges i hånden i `DigestAuth` og gensendes én gang ved 401.
3. Selvsigneret certifikat accepteres **kun** for den konfigurerede værtsadresse
   (`SelfSignedTrust`). Alt andet går gennem normal ATS.
4. Anmodninger paces med 120 ms mellemrum — samme grænse som desktop-versionen,
   fordi TV'ets webserver er skrøbelig ved burst-trafik.

### Parring

Præcis samme flow som desktop:

```
POST /6/pair/request   → auth_key + timestamp
signature = base64(hex(HMAC-SHA1(secret, timestamp + pin)))
POST /6/pair/grant     → credentials gemmes i Keychain
```

Hemmeligheden ligger i `PairingConstant.secret` og er Philips' offentlige
parringssecret — den er identisk på alle 2016+ modeller.

---

## Sikkerhed

- Parringscredentials ligger i **Keychain** (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`),
  ikke i UserDefaults.
- Kun private IPv4-adresser accepteres. Appen kan ikke peges mod internettet.
- Ingen analytics, ingen tredjeparts-SDK'er, ingen netværkstrafik ud af huset.
- `NSAllowsArbitraryLoads` er slået til fordi Philips' HTTP-endpoint på 1925 er
  ren HTTP og TV'et ikke altid har et gyldigt certifikat. Det er begrænset til
  LAN i praksis af adressevalideringen.

---

## Næste skridt

- [ ] Optagelseslisten som egen skærm (`recordings()` er klar i klienten)
- [ ] Widget: power, volumen, kanal
- [ ] Apple Watch-komplikation
- [ ] Genveje-app: "Film" sætter HDMI 1 + Ambilight Game
- [ ] Automatisk fund af TV via SSDP/mDNS i stedet for manuel IP
