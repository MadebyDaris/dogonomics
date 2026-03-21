import asyncio
import os
import sys
import json

# Try to import required packages
try:
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.sse import sse_client
    from mcp.types import CallToolRequest
    import ollama
except ImportError:
    print("Error: Missing dependencies.")
    print("Please install them using: pip install mcp ollama")
    sys.exit(1)

# Configuration
MCP_SERVER_URL = os.getenv("MCP_SERVER_URL", "http://localhost:8081/mcp/sse")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3")

async def main():
    print(f"Connecting to MCP server at {MCP_SERVER_URL}...")
    
    try:
        # Connect via SSE
        async with sse_client(MCP_SERVER_URL) as streams:
            async with ClientSession(streams[0], streams[1]) as session:
                await session.initialize()
                
                # List tools
                tools_result = await session.list_tools()
                tools = tools_result.tools
                tool_names = [t.name for t in tools]
                print(f"Connected! Available tools: {tool_names}")
                
                # Convert MCP tools to Ollama tools format
                ollama_tools = []
                for tool in tools:
                    ollama_tools.append({
                        "type": "function",
                        "function": {
                            "name": tool.name,
                            "description": tool.description,
                            "parameters": tool.inputSchema
                        }
                    })

                messages = []
                
                print(f"\nConnected to Dogonomics MCP. Using local model: {OLLAMA_MODEL}")
                print("Type your question (or 'quit' to exit):")
                
                while True:
                    try:
                        prompt = input("\n> ")
                        if prompt.lower() in ["quit", "exit"]:
                            break
                        
                        messages.append({"role": "user", "content": prompt})
                        
                        # First call to Ollama
                        print("Thinking...", end="", flush=True)
                        response = ollama.chat(
                            model=OLLAMA_MODEL,
                            messages=messages,
                            tools=ollama_tools,
                        )
                        
                        message = response['message']
                        messages.append(message)
                        
                        # Check for tool calls
                        if message.get('tool_calls'):
                            print(f"\n[Executing {len(message['tool_calls'])} tool calls...]")
                            
                            for tool_call in message['tool_calls']:
                                fn_name = tool_call['function']['name']
                                fn_args = tool_call['function']['arguments']
                                print(f"  -> Calling: {fn_name}({fn_args})")
                                
                                try:
                                    # Execute tool via MCP
                                    result = await session.call_tool(fn_name, arguments=fn_args)
                                    
                                    # Format result
                                    tool_content = ""
                                    if result.content:
                                        for content in result.content:
                                            if hasattr(content, 'text'):
                                                tool_content += content.text
                                            else:
                                                tool_content += str(content)
                                    
                                    # Truncate for display if too long
                                    display_content = tool_content
                                    if len(display_content) > 100:
                                        display_content = display_content[:100] + "..."
                                    print(f"  <- Result: {display_content}")
                                    
                                    # Add result to messages for Ollama
                                    # Note: Ollama/OpenAI API expects the tool response to be a separate message
                                    # usually with role='tool' and matching tool_call_id, but pure Ollama might differ slightly.
                                    # The 'mcp' library doesn't handle the Ollama chat loop, we do manually.
                                    
                                    messages.append({
                                        "role": "tool",
                                        "content": tool_content,
                                    })
                                except Exception as e:
                                    print(f"  XX Tool execution failed: {e}")
                                    messages.append({
                                        "role": "tool",
                                        "content": f"Error: {str(e)}"
                                    })
                            
                            # Second call to Ollama with tool results
                            print("Synthesizing answer...")
                            final_response = ollama.chat(
                                model=OLLAMA_MODEL,
                                messages=messages,
                            )
                            print("\nAI:", final_response['message']['content'])
                            messages.append(final_response['message'])
                        else:
                            print("\n\nAI:", message['content'])
                            
                    except KeyboardInterrupt:
                        break
                    except Exception as e:
                        print(f"\nError: {e}")
                        
    except Exception as e:
        print(f"\nFailed to connect to MCP server: {e}")
        print("Ensure the Dogonomics backend is running with MCP_ENABLED=true")

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nGoodbye!")
