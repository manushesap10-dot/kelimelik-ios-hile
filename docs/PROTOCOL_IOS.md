# Kelimelik Protocol (iOS rebuild)

Android RE ile aynı özel TCP protokolü kullanılır.

## Transport
- Host: `88.218.130.131`
- Port: `443` (fallback `30443`)
- TLS yok — düz binary frame

## Frame
```
[u32be payload_len][u16be name_len][name_utf8][body]
```

## Body list codec
- `u8 count`
- `0x00` + `u32be` int
- `0x07` + `u16be len` + utf8 string
- `0x01` / `0x02` bool

## Login
`GameModule_requestLogin`
- int pid
- str password_hex
- int 432

## Game
- `GameModule_requestGameInfo` / `GameModule_gameInfo`
  - board = 225 char
  - rack = short string (joker `#`)
- `GameModule_requestSubmitLetters`
  - int gameId
  - str word (lowercase)
  - int row (0-based)
  - int col (0-based)
  - int dir (0=H, 1=V)

## Success signals
- `GameModule_wordSubmitAccepted`
- `GameModule_spawnNewLetters`
- `GameModule_newTurn`
