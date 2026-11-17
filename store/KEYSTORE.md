# 업로드 키스토어 만들기 & GitHub 시크릿 등록

구글 플레이 스토어에 올릴 `.aab` 는 **업로드 키**로 서명해야 합니다.
이 문서는 내 컴퓨터에서 키스토어를 만들고, GitHub Actions(`.github/workflows/store.yml`)가 쓰도록 등록하는 방법입니다.

> 키스토어 파일(`.keystore`, `.jks`)과 비밀번호는 **절대 저장소(git)에 올리지 마세요.** 이 저장소에는 키스토어를 넣지 않습니다.

## 1. 키스토어 만들기 (내 컴퓨터에서, 한 번만)

JDK(Java)가 설치되어 있어야 `keytool` 을 쓸 수 있습니다. (없으면 Temurin JDK 17 이상 설치)

```bash
keytool -genkeypair -v \
  -keystore upload-keystore.jks \
  -alias upload \
  -keyalg RSA -keysize 2048 \
  -validity 10000
```

Windows PowerShell 에서는 줄바꿈 기호가 달라서 한 줄로 쓰는 게 편합니다.

```powershell
keytool -genkeypair -v -keystore upload-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

- 키스토어 비밀번호를 물어보면 길고 안전한 비밀번호를 정하세요. (이게 `KEYSTORE_PASSWORD`)
- 이름/조직 등은 편하게 입력해도 됩니다. (이름 정도만 적어도 됩니다)
- 최신 JDK 에서는 키 비밀번호를 따로 묻지 않고 키스토어 비밀번호를 그대로 씁니다. 따라서 `KEY_PASSWORD` 에는 `KEYSTORE_PASSWORD` 와 같은 값을 넣으세요. (따로 물어보면 Enter 로 같게 하세요.)
- alias 는 위 명령 그대로 `upload` 이므로 `KEY_ALIAS` 는 `upload` 입니다.
- `-validity 10000` 은 약 27년입니다. (플레이 스토어 요구: 25년 이상)

확인:

```bash
keytool -list -v -keystore upload-keystore.jks -alias upload
```

## 2. base64 로 바꾸기

GitHub 시크릿에는 파일을 그대로 넣을 수 없어서 텍스트(base64)로 바꿉니다. 결과는 **한 줄짜리 긴 문자열**입니다.

**Linux**

```bash
base64 -w 0 upload-keystore.jks > upload-keystore.b64
```

**macOS**

```bash
base64 -i upload-keystore.jks | tr -d '\n' > upload-keystore.b64
```

**Windows (PowerShell)**

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Content -NoNewline upload-keystore.b64
```

`upload-keystore.b64` 파일을 열어 내용 전체를 복사해 두세요. (등록 후에는 이 `.b64` 파일도 지우거나 안전한 곳에만 보관)

## 3. GitHub 시크릿 4개 등록

저장소 페이지에서 **Settings > Secrets and variables > Actions > New repository secret** 으로 아래 4개를 각각 추가합니다.

| 시크릿 이름 | 값 |
|---|---|
| `KEYSTORE_BASE64` | 2번에서 만든 base64 문자열 전체 |
| `KEYSTORE_PASSWORD` | 키스토어 비밀번호 |
| `KEY_ALIAS` | `upload` |
| `KEY_PASSWORD` | 키 비밀번호 (키스토어 비밀번호와 같게 했다면 같은 값) |

4개가 모두 있으면 워크플로가 서명된 `.aab` 를 만들고, 하나라도 없으면 **서명 안 된(UNSIGNED) .aab** 를 만들고 경고만 남깁니다. (플레이 스토어에는 올릴 수 없음)

빌드는 **Actions 탭 > Build Play Store AAB > Run workflow** 로 직접 실행하거나, `v1.0.0` 같은 태그를 push 하면 시작됩니다. 결과 `.aab` 는 해당 실행 페이지의 Artifacts 에서 받을 수 있습니다. (30일 보관)

## 4. 반드시 백업하세요

- `upload-keystore.jks` 파일, 키스토어 비밀번호, 키 비밀번호, alias(`upload`)를 **여러 곳에 따로 백업**하세요. (비밀번호 관리자, 외장 USB, 개인 클라우드 등)
- GitHub 시크릿은 한 번 저장하면 값을 다시 볼 수 없습니다. 백업은 내 컴퓨터/보관함에만 있습니다.
- 파일이나 비밀번호가 유출되면 다른 사람이 내 앱 업데이트를 서명할 수 있으니, 공개 저장소·메신저·이메일에 올리지 마세요.

## 5. Play App Signing 참고

- 플레이 콘솔의 **Play App Signing** 을 쓰면(신규 앱은 기본), 사용자에게 배포되는 실제 **앱 서명 키는 구글이 보관**하고, 내가 만든 키는 **업로드 키**로만 쓰입니다.
- 그래서 업로드 키를 잃어버려도 앱이 사라지지는 않습니다. 플레이 콘솔의 **앱 무결성(App integrity) > 업로드 키 재설정** 으로 구글에 새 업로드 키 인증서를 등록해 복구할 수 있습니다. (다만 승인에 시간이 걸리니 백업이 최선입니다.)
- 첫 `.aab` 를 올릴 때 Play App Signing 에 등록하면 됩니다. 이후 업데이트도 같은 업로드 키로 서명한 `.aab` 만 올릴 수 있습니다.
- `versionCode` 는 워크플로의 실행 번호(`run_number`)로 자동 증가합니다. 단, Actions 에서 "Re-run" 을 누르면 같은 번호가 다시 나오니, 업로드용은 **Run workflow** 로 새로 실행하거나 새 태그를 푸시하세요.
