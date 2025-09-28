#!/usr/bin/env python3
"""
Working MCP Server for Swift/iOS Development
"""

import asyncio
import json
import subprocess
import os
from pathlib import Path
from typing import Any, Dict, List

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.server.models import InitializationOptions
from mcp.types import (
    CallToolRequest,
    CallToolResult,
    ListToolsRequest,
    ListToolsResult,
    Tool,
    TextContent,
)

# Initialize the MCP server
server = Server("swift-ios-mcp-server")

# Project root directory
PROJECT_ROOT = Path("/Users/prateek/Projects/Puff Puff Pass")

@server.list_tools()
async def handle_list_tools() -> List[Tool]:
    """List available tools for Swift/iOS development"""
    return [
        Tool(
            name="build_project",
            description="Build the Swift iOS project",
            inputSchema={
                "type": "object",
                "properties": {
                    "scheme": {
                        "type": "string",
                        "description": "Xcode scheme to build",
                        "default": "Puff Puff Pass"
                    }
                }
            }
        ),
        Tool(
            name="get_swift_files",
            description="Get list of Swift files in the project",
            inputSchema={
                "type": "object",
                "properties": {}
            }
        ),
        Tool(
            name="analyze_project",
            description="Analyze Swift project structure",
            inputSchema={
                "type": "object",
                "properties": {}
            }
        )
    ]

@server.call_tool()
async def handle_call_tool(name: str, arguments: Dict[str, Any]) -> List[TextContent]:
    """Handle tool calls for Swift/iOS development"""
    
    if name == "build_project":
        return await build_project(arguments)
    elif name == "get_swift_files":
        return await get_swift_files(arguments)
    elif name == "analyze_project":
        return await analyze_project(arguments)
    else:
        return [TextContent(type="text", text=f"Unknown tool: {name}")]

async def build_project(args: Dict[str, Any]) -> List[TextContent]:
    """Build the Swift project"""
    scheme = args.get("scheme", "Puff Puff Pass")
    
    try:
        os.chdir(PROJECT_ROOT)
        
        cmd = [
            "xcodebuild",
            "-scheme", scheme,
            "-destination", "platform=iOS Simulator,name=iPhone 15",
            "build"
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        
        if result.returncode == 0:
            return [TextContent(type="text", text=f"✅ Build successful!\n\n{result.stdout}")]
        else:
            return [TextContent(type="text", text=f"❌ Build failed!\n\nError: {result.stderr}")]
            
    except Exception as e:
        return [TextContent(type="text", text=f"❌ Build error: {str(e)}")]

async def get_swift_files(args: Dict[str, Any]) -> List[TextContent]:
    """Get list of Swift files in the project"""
    try:
        swift_files = []
        for root, dirs, files in os.walk(PROJECT_ROOT):
            for file in files:
                if file.endswith('.swift'):
                    swift_files.append(os.path.join(root, file))
        
        if swift_files:
            files_text = "\n".join([f"📄 {f}" for f in swift_files])
            return [TextContent(type="text", text=f"Found {len(swift_files)} Swift files:\n\n{files_text}")]
        else:
            return [TextContent(type="text", text="No Swift files found")]
            
    except Exception as e:
        return [TextContent(type="text", text=f"❌ Error: {str(e)}")]

async def analyze_project(args: Dict[str, Any]) -> List[TextContent]:
    """Analyze Swift project structure"""
    try:
        analysis = {
            "project_files": [],
            "swift_files": [],
        }
        
        for root, dirs, files in os.walk(PROJECT_ROOT):
            for file in files:
                if file.endswith(('.xcodeproj', '.xcworkspace')):
                    analysis["project_files"].append(os.path.join(root, file))
                elif file.endswith('.swift'):
                    analysis["swift_files"].append(os.path.join(root, file))
        
        analysis_text = f"""
📊 Swift Project Analysis:

📁 Project Files: {len(analysis['project_files'])}
{chr(10).join([f"  • {f}" for f in analysis['project_files']])}

📄 Swift Files: {len(analysis['swift_files'])}
{chr(10).join([f"  • {f}" for f in analysis['swift_files'][:10]])}
{'  ... and more' if len(analysis['swift_files']) > 10 else ''}
"""
        
        return [TextContent(type="text", text=analysis_text)]
        
    except Exception as e:
        return [TextContent(type="text", text=f"❌ Analysis error: {str(e)}")]

async def main():
    """Main function to run the MCP server"""
    async with stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            InitializationOptions(
                server_name="swift-ios-mcp-server",
                server_version="1.0.0",
                capabilities=server.get_capabilities(
                    notification_options=None,
                    experimental_capabilities=None,
                ),
            ),
        )

if __name__ == "__main__":
    asyncio.run(main())
