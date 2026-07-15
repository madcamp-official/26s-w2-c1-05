"""LLM 프록시 (규칙 #4): 키 은닉 + task별 vLLM/Gemini 분기 + SSE 패스스루.

태스크 배분(FSD §6.2): boss_turn·incremental → vLLM / final_judge·scenario → Gemini.
LLM_FALLBACK=gemini 설정 시 전 태스크 Gemini 강제(데모 보험).
요청/응답은 llm_logs에 기록(QLoRA 데이터, FSD §6.4).
"""

import asyncio
import json
import os
import time

import httpx
from fastapi import APIRouter
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from . import db

router = APIRouter()

VLLM_TASKS = {"boss_turn", "incremental"}


class ChatRequest(BaseModel):
    task: str  # boss_turn | incremental | final_judge | scenario
    messages: list[dict]  # [{role, content}] (OpenAI 형식)
    temperature: float | None = None
    max_output_tokens: int | None = None
    session_id: str | None = None


def _backend_for(task: str) -> str:
    if os.getenv("LLM_FALLBACK") == "gemini":
        return "gemini"
    if task in VLLM_TASKS and os.getenv("VLLM_BASE_URL"):
        return "vllm"
    return "gemini"


@router.post("/llm/chat")
async def chat(req: ChatRequest):
    backend = _backend_for(req.task)
    stream = _stream_vllm(req) if backend == "vllm" else _stream_gemini(req)
    return StreamingResponse(_logged(req, backend, stream), media_type="text/event-stream")


async def _logged(req: ChatRequest, backend: str, stream):
    """스트림을 그대로 흘리며 전체 응답을 모아 llm_logs에 기록.
    finally: 클라이언트가 중간에 끊어도(통화 중단) 부분 응답까지 기록 — QLoRA 데이터 유실 방지."""
    started = time.monotonic()
    full: list[str] = []
    try:
        async for delta in stream:
            full.append(delta)
            yield f"data: {json.dumps({'text': delta}, ensure_ascii=False)}\n\n"
        yield "data: [DONE]\n\n"
    finally:
        # 취소된 태스크 안에서 await하면 다시 CancelledError → 별도 태스크로 분리 기록.
        if db.pool:
            asyncio.create_task(db.pool.execute(
                "INSERT INTO llm_logs (task, model, session_id, request, response, latency_ms)"
                " VALUES ($1, $2, $3, $4, $5, $6)",
                req.task,
                backend,
                req.session_id,
                json.dumps(req.messages, ensure_ascii=False),
                json.dumps({"text": "".join(full)}, ensure_ascii=False),
                int((time.monotonic() - started) * 1000),
            ))


async def _stream_gemini(req: ChatRequest):
    key = os.getenv("GEMINI_API_KEY", "")
    model = os.getenv("GEMINI_MODEL", "gemini-flash-lite-latest")
    system = "\n".join(m["content"] for m in req.messages if m["role"] == "system")
    contents = [
        {"role": "model" if m["role"] == "assistant" else "user", "parts": [{"text": m["content"]}]}
        for m in req.messages
        if m["role"] != "system"
    ]
    body = {
        "contents": contents,
        "generationConfig": {
            "temperature": req.temperature if req.temperature is not None else 0.9,
            "maxOutputTokens": req.max_output_tokens or 256,
            "thinkingConfig": {"thinkingBudget": 0},
        },
    }
    if system:
        body["system_instruction"] = {"parts": [{"text": system}]}
    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"{model}:streamGenerateContent?alt=sse&key={key}"
    )
    async with httpx.AsyncClient(timeout=60) as client:
        async with client.stream("POST", url, json=body) as r:
            r.raise_for_status()
            async for line in r.aiter_lines():
                if not line.startswith("data:"):
                    continue
                data = line[5:].strip()
                if not data or data == "[DONE]":
                    continue
                for cand in json.loads(data).get("candidates", []):
                    for part in (cand.get("content") or {}).get("parts", []):
                        if part.get("text"):
                            yield part["text"]


async def _stream_vllm(req: ChatRequest):
    base = os.getenv("VLLM_BASE_URL", "").rstrip("/")
    body = {
        "model": os.getenv("VLLM_MODEL", ""),
        "messages": req.messages,
        "temperature": req.temperature if req.temperature is not None else 0.7,
        # top_p<1 로 뉴클리어스 절단, repetition_penalty 로 반복 억제 — 둘 다 안 주면
        # vLLM 기본(top_p=1.0)이라 Qwen3-AWQ가 저확률 CJK 토큰으로 코드스위칭(중국어 섞임)함.
        "top_p": 0.8,
        "repetition_penalty": 1.05,
        "max_tokens": req.max_output_tokens or 256,
        "stream": True,
        # Qwen3: thinking 비활성 (안 끄면 <think>로 지연 폭증 — Gemini 때와 같은 함정)
        "chat_template_kwargs": {"enable_thinking": False},
    }
    async with httpx.AsyncClient(timeout=60) as client:
        async with client.stream("POST", f"{base}/v1/chat/completions", json=body) as r:
            r.raise_for_status()
            async for line in r.aiter_lines():
                if not line.startswith("data:"):
                    continue
                data = line[5:].strip()
                if not data or data == "[DONE]":
                    continue
                delta = json.loads(data)["choices"][0].get("delta", {})
                if delta.get("content"):
                    yield delta["content"]
