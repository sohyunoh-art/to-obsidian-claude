# to-obsidian-claude

> Languages: [English](README.md) | **한국어**

코드 기반 마크다운 문서(PROJECT_MAP, 코드 분석, 아키텍처 노트…)를
**Obsidian 볼트**로 신뢰성 있게 게시하는 Claude Code 헬퍼.

견고한 단일 bash 백엔드를 공유하는 **두 가지 형태**로 제공됩니다:

- 🤖 **`obsidian-publisher` 서브에이전트** — 위임 모드. 한 줄로 부르면 서브에이전트가
  전 과정을 처리해서 메인 대화가 깔끔합니다. "맡겨두기" 패턴과 여러 레포 병렬 처리에 좋습니다.
- 🧩 **`to-obsidian` 스킬** — 진행 중인 대화 안에서 인라인으로 게시. 이미 어떤 문서를
  논의 중이고 그대로 옵시디언에 옮기고 싶을 때 좋습니다.

둘 다 `publish-obsidian.sh`를 호출합니다 — 견고함의 진짜 출처는 이 스크립트입니다.

## 왜 이게 필요한가

WSL에서 OneDrive 동기화 중인 옵시디언 볼트에 파일을 쓰는 게 의외로 까다롭습니다.
기본 에디터/에이전트 파일 쓰기 도구가 `/mnt/c/.../OneDrive/...` 경로에 쓸 때
**파일을 엉뚱한 하위 폴더에 떨어뜨릴 수** 있습니다 — WSL의 9p drvfs 캐시와
OneDrive Files-On-Demand 가상화 레이어가 비결정적으로 작동하기 때문입니다.
"이 문서를 볼트에 넣기"가 조용히 깨지는 버그죠.

이 도구는 다음으로 우회합니다:

1. 평범한 bash `cp` 사용(이건 안정적임) + **쓰기 후 바이트 패리티 검증** + 1회 재시도.
2. 옵시디언의 `obsidian.json`에서 볼트 경로를 **동적으로 해석** — 볼트를 이름으로 부를 수 있고
   머신/Windows 사용자가 달라도 동작.
3. 직접 만들지 않은 노트는 덮어쓰기 거부(프론트매터 마커 `generated-by: to-obsidian`로 식별).
   `--force` 명시 시에만 덮어씀.
4. **동일 basename 노트 중복 시 경고** — `obsidian://open?file=…` URI는 basename으로 해석되므로
   중복이 있으면 URI가 모호해집니다.

Obsidian을 *통해* 쓰고 싶으시면(파일시스템 버그 완전 우회), [Local REST API 플러그인](https://github.com/coddingtonbear/obsidian-local-rest-api)
+ [obsidian-mcp-server](https://github.com/cyanheads/obsidian-mcp-server)로 **MCP 백엔드**도 옵션입니다.
[`skills/to-obsidian/SETUP.md`](skills/to-obsidian/SETUP.md) 참고. 스킬/서브에이전트가 MCP를
자동 감지해서 우선 사용합니다.

## 특징

- ✅ 외부 설치 0으로 **오늘 바로 동작** (bash 백엔드, MCP 불필요)
- ✅ 한 줄 설치 (`./install.sh`)
- ✅ 볼트를 **이름으로** 동적 해석 (머신마다 다른 경로 OK)
- ✅ 재게시 안전 마커가 들어간 YAML 프론트매터
- ✅ 레포 상대경로 마크다운 링크 자동 변환 (볼트에서 깨진 링크 0)
- ✅ 손으로 쓴 노트 덮어쓰기 거부
- ✅ 중복 노트명 경고 (`obsidian://` URI 결정성 보존)
- ✅ **스킬**과 **서브에이전트** 양쪽 제공 — 취향대로 호출 방식 선택
- 🧰 옵시디언을 통한 견고한 게시용 옵션 MCP 백엔드

## 설치

```bash
git clone https://github.com/<your-username>/to-obsidian-claude.git
cd to-obsidian-claude
./install.sh
```

설치 후 Claude Code를 재시작(또는 새 세션 시작)하면 에이전트와 스킬이 인식됩니다.

제거: `./install.sh --uninstall`.

### 요구사항

- [Claude Code](https://claude.com/claude-code)
- bash, `python3` (`obsidian.json`을 통한 볼트 이름 해석용)
- Obsidian 볼트 — 이름과 경로는 상관없음, `obsidian.json`을 읽어 처리합니다
- (선택 MCP 업그레이드) Node.js + npm, Obsidian **Local REST API** 플러그인,
  WSL 미러 네트워킹 — `SETUP.md` 참고

## 사용법

설치 후 Claude Code 세션에서:

**서브에이전트 (위임 모드):**
> "이 PROJECT_MAP.md를 MyVault의 'code-analysis' 노트에 넣어줘"
>
> 또는 `obsidian://open?vault=MyVault&file=...` URI 붙여넣기.

Claude가 obsidian-publisher의 description을 감지해서 위임합니다. 서브에이전트가
별도 컨텍스트에서 실행되어 bash 스크립트(또는 등록된 MCP)를 호출하고 결과만 보고합니다.

**스킬 (인라인 모드):**
> "이 문서 옵시디언에 publish해줘 (vault=MyVault, note=architecture.md)"

메인 세션이 스킬 단계를 인라인으로 실행해서, 대화 흐름을 유지합니다.

**스크립트 직접 호출 (Claude 없이):**
```bash
~/.claude/skills/to-obsidian/scripts/publish-obsidian.sh \
  --vault "MyVault" \
  --note  "code-analysis.md" \
  --source "/path/to/your-doc.md"
```

### 폴더/파일명 자유롭게

`--note`는 **볼트 루트 기준 상대경로**라서 중첩 폴더든 한글 폴더든 다 됩니다.
없는 폴더는 자동 생성됩니다(`mkdir -p`):

| 원하는 결과 | `--note` 값 | 결과 위치 |
|---|---|---|
| 루트 노트 | `code-map.md` | `MyVault/code-map.md` |
| 폴더 안 | `코드분석/navlue.md` | `MyVault/코드분석/navlue.md` |
| 깊은 중첩 | `work/2026/Q2/arch.md` | `MyVault/work/2026/Q2/arch.md` |

## 옵션 & 환경변수

bash 백엔드가 지원하는 옵션 (v0.2부터). 전부 선택사항이고, v0.1 호출 방식은 그대로 동작합니다.

| 플래그 | 동작 |
|--------|------|
| `--dry-run` | 모든 검사는 수행하되 **실제로 쓰지 않음**. 어디로 갈지(볼트/타깃/모드/소스크기/마커 유무) 미리 확인. |
| `--append` | 기존 노트에 이어쓰기 (없으면 생성). 안전 규칙은 동일 — 마커 없는 외부 노트는 `--force` 없이 거부됨. |
| `--ensure-marker` | 소스 frontmatter에 `generated-by: to-obsidian`이 없으면 자동 주입 (frontmatter 자체가 없으면 최소 블록 생성). 기본 off — 호출자가 직접 frontmatter를 관리하는 경우 그대로 유지. |
| `--force` | 안전 마커 없는 노트 덮어쓰기/이어쓰기 허용. 외부 콘텐츠용 escape hatch. |

| 환경변수 | 동작 |
|----------|------|
| `OBSIDIAN_DEFAULT_VAULT` | `--vault` 생략 시 사용할 기본 볼트. 셸에 한 번 export 해두면 주력 볼트 호출 시 `--vault` 안 쳐도 됨. |
| `OBSIDIAN_DEFAULT_FOLDER` | `--note`가 절대경로가 아닐 때 앞에 붙는 폴더 prefix. 모든 게시를 `code-maps/`나 `daily/` 같은 데로 라우팅할 때 유용. |

### 예시

```bash
# 게시 전 미리보기
~/.claude/skills/to-obsidian/scripts/publish-obsidian.sh \
  --vault MyVault --note "code-analysis.md" --source ./PROJECT_MAP.md --dry-run

# 일일 로그에 섹션 이어쓰기
publish-obsidian.sh --vault MyVault --note "daily/2026-05-28.md" \
  --source ./morning-notes.md --append

# frontmatter 없는 마크다운 파일을 안전하게 게시
publish-obsidian.sh --vault MyVault --note "imports/raw.md" \
  --source ./external.md --ensure-marker

# 셸 세션 기본값 한 번 설정
export OBSIDIAN_DEFAULT_VAULT=MyVault
export OBSIDIAN_DEFAULT_FOLDER=code-maps
publish-obsidian.sh --note "navlue.md" --source ./map.md
# → MyVault/code-maps/navlue.md 에 게시됨
```

`publish-obsidian.sh --help` 로 전체 목록을 인라인으로 볼 수 있습니다.

## 레이아웃

```
to-obsidian-claude/
├── agents/obsidian-publisher.md   → ~/.claude/agents/ 로 설치
├── skills/to-obsidian/
│   ├── SKILL.md                   → ~/.claude/skills/to-obsidian/ 로 설치
│   └── SETUP.md                   (MCP 백엔드 설정, 선택)
├── scripts/publish-obsidian.sh    → ~/.claude/skills/to-obsidian/scripts/ 로 설치
├── install.sh
├── LICENSE   (MIT)
├── CHANGELOG.md
├── README.md       (English)
└── README.ko.md    (한국어)
```

## 배경: WSL+OneDrive 버그

호기심 차원에서 — 실패 양상은 이렇습니다: 기본 에디터 도구로
`/mnt/c/Users/<you>/OneDrive/Documents/<vault>/<note>.md` 같은 절대경로에 파일을 쓰면,
실제로는 사용자가 지정하지 않은 **중첩 하위 폴더 안에** 파일이 생기고 — 보통 그 타깃의
사전 존재 플레이스홀더를 대체합니다. `readlink`로 보면 심볼릭링크는 없습니다.
사전 존재 루트 파일은 사라집니다. 같은 경로에 평범한 bash `cp`로 다시 시도하면
정상 작동합니다.

근본 원인은 WSL2의 9p drvfs(`cache=0x5`)와 OneDrive Files-On-Demand의
reparse-point / dehydration 로직 간 상호작용으로 보입니다. 이 도구의 bash 백엔드는
`cp` + 쓰기 후 크기 검증 + 재시도로 이를 완전히 우회합니다.

## 기여

이슈와 PR을 환영합니다. 이 도구는 의도적으로 미니멀합니다 — 가치의 대부분은
`publish-obsidian.sh`에 인코딩된 소수의 정확성 불변식에 있습니다. 새로운 실패 양상이
보이면 최소 재현 가능 케이스와 함께 알려주세요.

## 라이선스

MIT — [LICENSE](LICENSE) 참고.
