# StraBot 설치 파일

업비트 · 빗썸 원화 마켓에서 **내가 정한 규칙대로** 사고파는 설치형 자동매매 프로그램 StraBot 의 설치 파일을 나누는 곳이에요.
프로그램과 거래소 API 키는 내 PC(또는 내 서버)에만 있고, 실제 주문 전에 시뮬레이션으로 충분히 시험해 볼 수 있어요.

- 홈페이지 · 사용 안내: https://strabot.mayai.kr
- 개선 요청 · 문제 신고: https://strabot.mayai.kr/feedback
- 무료 프로그램이에요. MAYAi 그룹이 만들어요.

> StraBot은 규칙을 **실행**해 주는 도구예요. 어떤 코인을 사라고 권하지 않고, 수익을 약속하지 않으며, 가상자산은 원금을 잃을 수 있어요.
> 실제 주문을 켜기 전에 [위험 고지](https://strabot.mayai.kr/risk)를 꼭 읽어 주세요.

## Windows

[최신 릴리스](https://github.com/hongrolee/strabot-releases/releases/latest)에서 `StraBot_Setup.exe` 를 받아 실행해요.
홈페이지(https://strabot.mayai.kr)의 다운로드 단추도 같은 파일이에요. 함께 있는 `.sha256` 파일로 받은 파일이 맞는지 확인할 수 있어요.

## 리눅스 서버 (우분투 22.04+ · 데비안 12+ · x86_64)

PC를 끄지 않고 24시간 돌리고 싶을 때. root(또는 sudo) 로 들어가서:

```bash
curl -fsSL https://strabot.mayai.kr/install.sh | sudo bash
```

설치하는 동안 **대시보드 비밀번호**(8자 이상, 브라우저로 접속할 때 쓰는 것)를 한 번 물어요. 끝나면 `http://서버IP:5001` 로 접속해요.
설치 스크립트는 이 저장소의 [install.sh](install.sh) 예요. 최신 `strabot-linux-x86_64.tar.gz` 를 받아 확인값(sha256)을 검사한 뒤
`/opt/strabot` 에 놓고, 전용 사용자 `strabot` 와 systemd 서비스를 만들어요. 설정 · 키 · 기록은 `/var/lib/strabot` 에 있어요.

| 명령 | 뜻 |
|---|---|
| `strabot status` · `strabot logs` | 상태 · 버전 · 접속 주소 · 실시간 로그 |
| `strabot update` | 최신 버전을 받아 다시 켬 (봇 · 설정은 그대로) |
| `strabot password` · `strabot port 5001` | 대시보드 비밀번호 · 포트 바꾸기 |
| `strabot start` · `stop` · `restart` · `uninstall` | 켜기 · 끄기 · 다시 켜기 · 지우기(설정 · 기록은 남김) |

자세한 안내(방화벽 · 업비트 허용 IP · https): https://strabot.mayai.kr/linux

## 라이선스

StraBot 은 무료로 쓸 수 있는 비공개 소프트웨어예요. 프로그램을 다시 배포하거나 고쳐서 배포하기, 되팔기, 역설계는 허락하지 않아요.
자세한 조건은 [이용약관](https://strabot.mayai.kr/terms)에 있고, 함께 들어 있는 오픈소스 구성요소는 [오픈소스 고지](https://strabot.mayai.kr/licenses)에 있어요.

**StraBot · MAYAi 이름과 로고는 MAYAi 의 표시예요.**

문의: contact@mayai.kr
