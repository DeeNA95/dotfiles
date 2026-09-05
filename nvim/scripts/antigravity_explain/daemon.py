import asyncio
import os

from exa_py import Exa
from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse
from google.antigravity import Agent, LocalAgentConfig
from pydantic import BaseModel

app = FastAPI()

# Hold initialized SDKs at the global scope for persistent state
exa_api_key = os.environ.get("EXA_API_KEY")
exa = Exa(api_key=exa_api_key) if exa_api_key else None


class Payload(BaseModel):
    filetype: str
    code_snippet: str
    full_file_context: str | None = ""
    framework_context: str | None = ""
    diagnostics: str | None = "No LSP errors/warnings."
    chat_history: str | None = ""


async def stream_openai_compatible(
    *, api_key: str, base_url: str | None, model: str, prompt_text: str
):
    from openai import AsyncOpenAI

    client = AsyncOpenAI(api_key=api_key, base_url=base_url)
    response = await client.chat.completions.create(
        model=model,
        messages=[{"role": "user", "content": prompt_text}],
        stream=True,
    )
    async for chunk in response:
        content = chunk.choices[0].delta.content
        if content:
            yield content


async def generate_response(prompt_text: str, strip_markdown: bool = False):
    """
    Generator that streams the response from the active LLM.
    If strip_markdown is True (for Refactor), it will strip out ``` and language tags.
    Since it's a stream, stripping markdown perfectly on the fly is tricky.
    We will just yield tokens and let Neovim or basic filtering handle it, or we buffer slightly.
    For simplicity, we'll strip ``` and ```<lang> from tokens as they come, though tokens might be split.
    A simpler approach: just yield the tokens. If we want structured output natively, we do it in prompt.
    """

    # We will buffer the first few tokens to catch markdown tags
    # Actually, a simple prompt is usually enough to prevent backticks,
    # but we will just pass it straight through for now.

    # 1. DeepSeek V4 Pro (primary reviewer and code explainer)
    deepseek_key = os.environ.get("DEEPSEEK_API_KEY")
    if deepseek_key:
        try:
            async for content in stream_openai_compatible(
                api_key=deepseek_key,
                base_url="https://api.deepseek.com",
                model="deepseek-v4-pro",
                prompt_text=prompt_text,
            ):
                yield content.replace("```", "") if strip_markdown else content
            return
        except Exception as e:
            yield f"\n[DeepSeek V4 Pro Error: {e}]\n"

    # 2. Gemini (via Antigravity SDK)
    gemini_key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GEMINI_KEY")
    if gemini_key:
        # Set it explicitly in the environment for the SDK if it's only in GEMINI_KEY
        os.environ["GEMINI_API_KEY"] = gemini_key
        try:
            config = LocalAgentConfig()
            async with Agent(config) as agent:
                response = await agent.chat(prompt_text)
                async for token in response:
                    if strip_markdown:
                        token = token.replace(
                            "```" + prompt_text.split("```")[0].strip(), ""
                        ).replace("```", "")
                    yield token
            return
        except Exception as e:
            pass
            # yield f"\n[Gemini Error: {e}]\n"

    # 3. OpenRouter (DeepSeek V4 Flash)
    if os.environ.get("OPENROUTER_API_KEY"):
        try:
            async for content in stream_openai_compatible(
                api_key=os.environ["OPENROUTER_API_KEY"],
                base_url="https://openrouter.ai/api/v1",
                model="deepseek/deepseek-v4-flash",
                prompt_text=prompt_text,
            ):
                yield content.replace("```", "") if strip_markdown else content
            return
        except Exception as e:
            yield f"\n[OpenRouter Error: {e}]\n"

    # 4. OpenAI
    if os.environ.get("OPENAI_API_KEY"):
        try:
            async for content in stream_openai_compatible(
                api_key=os.environ["OPENAI_API_KEY"],
                base_url=None,
                model="gpt-5.4-mini",
                prompt_text=prompt_text,
            ):
                yield content.replace("```", "") if strip_markdown else content
            return
        except Exception as e:
            yield f"\n[OpenAI Error: {e}]\n"

    # 5. Claude
    if os.environ.get("CLAUDE_API_KEY"):
        try:
            from anthropic import AsyncAnthropic

            client = AsyncAnthropic(api_key=os.environ.get("CLAUDE_API_KEY"))
            async with client.messages.stream(
                model="claude-haiku-4-5-20251001",
                max_tokens=2048,
                messages=[{"role": "user", "content": prompt_text}],
            ) as stream:
                async for text in stream.text_stream:
                    if strip_markdown:
                        text = text.replace("```", "")
                    yield text
            return
        except Exception as e:
            yield f"\n[Claude Error: {e}]\n"

    yield "Error: All models in the fallback chain failed or no API keys were configured.\n"


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/explain")
async def explain(payload: Payload):
    # Perform Exa search
    context = ""
    if exa:
        search_query = (
            f"documentation for {payload.filetype} code: {payload.code_snippet[:100]}"
        )
        try:
            search_response = exa.search(
                search_query, num_results=2, type="auto", contents={"highlights": True}
            )
            context_parts = []
            for res in search_response.results:
                content = (
                    "\\n".join(res.highlights)
                    if hasattr(res, "highlights") and res.highlights
                    else getattr(res, "text", "")[:1000]
                )
                context_parts.append(f"Source ({res.url}):\\n{content}")
            context = "\\n\\n".join(context_parts)
        except Exception as e:
            context = f"Failed to retrieve Exa search context: {e}"

    prompt = f"""You are Pennyworth, a principal code reviewer and highly advanced code explainer.
Analyze the following {payload.filetype} code snippet.

Workspace Framework Info: {payload.framework_context}

LSP Diagnostics for this code:
{payload.diagnostics}

Code Snippet (Focus on this):
```{payload.filetype}
{payload.code_snippet}
```

Full File Context (For reference only):
```{payload.filetype}
{payload.full_file_context}
```

Documentation Context from web search:
{context}

Act as the first reviewer: prioritize correctness bugs, security risks, regressions, and missing tests before style suggestions.
Provide a concise, markdown-formatted explanation of the code snippet, highlighting its purpose, potential issues, and best practices.
If there are any LSP Errors or Warnings, explain why they are happening and provide the exact fixed code to resolve them. Do not use conversational filler, just give the explanation.
"""
    return StreamingResponse(generate_response(prompt), media_type="text/plain")


@app.post("/refactor")
async def refactor(payload: Payload):
    # NO Exa search to save latency!
    prompt = f"""You are an expert software engineer.
You are tasked with refactoring ONLY the specific code snippet provided below.

Workspace Framework Info: {payload.framework_context}

LSP Diagnostics:
{payload.diagnostics}

Original Code to Refactor (YOUR TARGET):
{payload.code_snippet}

Full File Context (FOR REFERENCE ONLY - DO NOT REWRITE THIS):
{payload.full_file_context}

CRITICAL INSTRUCTIONS:
1. Return STRICTLY the refactored version of the "Original Code to Refactor".
2. DO NOT return the "Full File Context". You must ONLY return the exact lines needed to replace the "Original Code to Refactor".
3. DO NOT wrap the code in markdown backticks (e.g., no ```python).
4. DO NOT include any conversational text or explanations.
5. The output MUST be a direct, pure-code drop-in replacement for the original snippet.
"""
    return StreamingResponse(
        generate_response(prompt, strip_markdown=True), media_type="text/plain"
    )


@app.post("/chat")
async def chat(payload: Payload):
    prompt = f"""You are Pennyworth, an expert software engineer and highly advanced code assistant.

Workspace Framework Info: {payload.framework_context}

Original Code Snippet ({payload.filetype}):
```{payload.filetype}
{payload.code_snippet}
```

LSP Diagnostics:
{payload.diagnostics}

Full File Context (For reference only):
```{payload.filetype}
{payload.full_file_context}
```

Conversation History:
{payload.chat_history}

Please reply directly to the latest message in the conversation history above. Be concise and use markdown formatting.
"""
    return StreamingResponse(generate_response(prompt), media_type="text/plain")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="127.0.0.1", port=8593, log_level="error")
