import asyncio
import os
import sys
import time

try:
    from mcp import ClientSession
    from mcp.client.sse import sse_client
    import ollama
except ImportError:
    print("Missing dependencies. Install with: pip install -r requirements.txt")
    sys.exit(1)

MCP_SERVER_URL = os.getenv("MCP_SERVER_URL", "http://dogonomics:8081/mcp/sse")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3")
OLLAMA_HEALTH_RETRIES = int(os.getenv("OLLAMA_HEALTH_RETRIES", "30"))
OLLAMA_HEALTH_DELAY_SECONDS = float(os.getenv("OLLAMA_HEALTH_DELAY_SECONDS", "2"))
MCP_RETRY_DELAY_SECONDS = float(os.getenv("MCP_RETRY_DELAY_SECONDS", "5"))
KEEPALIVE_SECONDS = int(os.getenv("MCP_CLIENT_KEEPALIVE_SECONDS", "30"))


def wait_for_ollama() -> bool:
    print("Waiting for Ollama API...")
    for attempt in range(1, OLLAMA_HEALTH_RETRIES + 1):
        try:
            ollama.list()
            print("Ollama is reachable.")
            return True
        except Exception as exc:
            print(f"Ollama not ready (attempt {attempt}/{OLLAMA_HEALTH_RETRIES}): {exc}")
            time.sleep(OLLAMA_HEALTH_DELAY_SECONDS)
    return False


def ensure_model() -> bool:
    print(f"Ensuring Ollama model is available: {OLLAMA_MODEL}")
    try:
        ollama.pull(OLLAMA_MODEL)
        print(f"Model ready: {OLLAMA_MODEL}")
        return True
    except Exception as exc:
        print(f"Failed to pull/check model {OLLAMA_MODEL}: {exc}")
        return False


async def run_mcp_bridge() -> None:
    while True:
        try:
            print(f"Connecting to MCP server: {MCP_SERVER_URL}")
            async with sse_client(MCP_SERVER_URL) as streams:
                async with ClientSession(streams[0], streams[1]) as session:
                    await session.initialize()
                    tools_result = await session.list_tools()
                    tool_names = [tool.name for tool in tools_result.tools]
                    print(f"Connected to MCP. Tools: {tool_names}")

                    # Keep the session warm and auto-reconnect on failures.
                    while True:
                        await asyncio.sleep(KEEPALIVE_SECONDS)
                        tools_result = await session.list_tools()
                        print(f"Heartbeat ok. Tool count: {len(tools_result.tools)}")
        except Exception as exc:
            print(f"MCP bridge disconnected: {exc}. Retrying in {MCP_RETRY_DELAY_SECONDS}s...")
            await asyncio.sleep(MCP_RETRY_DELAY_SECONDS)


async def main() -> None:
    if not wait_for_ollama():
        print("Ollama never became healthy. Exiting.")
        sys.exit(1)

    if not ensure_model():
        print("Model setup failed. Exiting.")
        sys.exit(1)

    await run_mcp_bridge()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("Shutting down MCP client service.")
