# 서버 배포 (camp-3) — systemd 유닛

재부팅 시 서비스 자동복구를 위한 systemd 유닛 (Phase 5). ExecStart는 tmux로
검증된 명령과 1:1 동일. cloudflared·PostgreSQL은 이미 systemd.

## 설치 (camp-3, root)

```bash
# 이 디렉터리의 .service 파일을 /etc/systemd/system/ 에 복사 후:
systemctl daemon-reload
systemctl enable yeoboseyo-vllm yeoboseyo-whisper yeoboseyo-game
```

`enable`만 하면 **재부팅 시 자동 시작**된다(현재 tmux를 멈추지 않아 무중단).

## 현재 런타임 상태 (2026-07-11 기준)

| 서비스 | 런타임 | 이유 |
|---|---|---|
| cloudflared, postgresql | systemd | 기존부터 |
| **yeoboseyo-whisper** | **systemd (전환 완료)** | 재배포 드묾, cutover 안전 |
| yeoboseyo-vllm | tmux (enable만) | 모델 재로딩 ~1–2분이라 개발 중 cutover 보류 |
| yeoboseyo-game | tmux (enable만) | Phase 3 담당자가 tmux로 재배포 중 → 충돌 방지 |

세 유닛 모두 `enable` 상태라 **다음 재부팅 시엔 전부 systemd로 자동 복구**된다.
tmux로 도는 vllm/game은 재부팅 전까지 그대로 유지된다(tmux와 systemd가 같은 포트를
동시에 잡지 않도록 systemd start는 하지 않았음).

## 데모 준비 시 최종 cutover (개발 종료 후)

게임서버 배포 방식을 tmux → systemd로 전환:

```bash
tmux kill-session -t vllm;  systemctl start yeoboseyo-vllm      # ~1–2분 로딩
tmux kill-session -t game;  systemctl start yeoboseyo-game
# 이후 게임서버 재배포는: (코드 갱신) → systemctl restart yeoboseyo-game
```

⚠️ 전환 후에는 `tmux new -s game ...` 재배포 금지(포트 8080 충돌). `systemctl restart`를 쓸 것.

## ⚠️ whisper GPU + CUDA 버전 (중요)

이 박스의 시스템 CUDA는 **13**(libcublas.so.13)인데 ctranslate2 4.x는 **CUDA 12**
(libcublas.so.12)·cuDNN 9를 요구한다. 그대로 두면 whisper가 모델은 GPU에 올리지만
전사(encode) 시점에 `RuntimeError: Library libcublas.so.12 is not found`로 크래시한다.

해결: whisper venv에 CUDA 12 라이브러리를 pip 설치하고 유닛의 LD_LIBRARY_PATH로 가리킨다.
```bash
/root/venvs/whisper/bin/pip install nvidia-cublas-cu12 nvidia-cudnn-cu12
# yeoboseyo-whisper.service의 Environment=LD_LIBRARY_PATH=.../nvidia/cublas/lib:.../nvidia/cudnn/lib
```
(대안: CPU 전사 — Environment=WHISPER_DEVICE=cpu, WHISPER_COMPUTE=int8. 느리지만 CUDA 불필요)

## 상태 확인

```bash
systemctl status yeoboseyo-whisper
systemctl is-enabled yeoboseyo-vllm yeoboseyo-whisper yeoboseyo-game
curl -s localhost:8080/health
```
