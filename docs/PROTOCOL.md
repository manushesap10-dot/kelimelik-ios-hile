# Kelimelik Protocol Notes (2026-07-24)

## Transport
- TCP: kelimelikserver.he2apps.com / 88.218.130.131
- Port 443 (fallback 30443)
- NOT TLS/HTTPS for game traffic. Plain custom frames on the socket.

## Frame format
```
[u32be payload_len][u16be name_len][name_utf8][body_bytes]
```
- No null between name and body.
- Empty args body = single `0x00` (count 0). Example: GameModule_requestPing

## Login (works from app + PC Python)
- Name: `GameModule_requestLogin`
- Body simple-list codec:
  - u8 count=3
  - `0x00` + u32be pid
  - `0x07` + u16be len + password_hex_utf8
  - `0x00` + u32be 432 (0x1b0, constant from app capture)
- Response: `GameModule_loginAccepted`

## Device info
- `GameModule_requestUpdateDeviceInfo`
- Body: count=2, str platform, str deviceId

## After login server push
- opponentStats, ligData, userGamesList, userInvitations
- userCompletedGamesList, userProfile, userGiftData, userPurchaseData

## Builds
- Frida gadget wait-mode: `yeni_cikti/kelimelik_frida3-aligned-debugSigned.apk`
- Scripts: `kelimelik_proto.js`, `kel_proto.py`, `kelimelik_ssl4.js`
- Capture: `/storage/emulated/0/Android/data/com.he2apps.kelimelik/files/kel_capture.txt`

## Current blocker for board
- This account `userGamesList` is EMPTY (no active game).
- Need open/in-progress game to capture `GameModule_gameInfo` / board fields.
- Create-game requests from PC currently get no useful response / connection abort after login burst.
- Best path: open a game in BlueStacks while Frida gadget capture is live.

## Wordlist
- `assets/flutter_assets/assets/data/wordlist.txt` (WORDS[... encrypted/encoded)
