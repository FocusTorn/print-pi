#!/usr/bin/env python3
"""
Simple script to detect comment prefixes based on file extension.
This is a basic implementation - you could extend it with more sophisticated detection.
"""

import os
import sys

# Comment prefix mapping based on file extensions
COMMENT_PREFIXES = {
    # Scripting languages
    '.py': '#',
    '.sh': '#', 
    '.bash': '#',
    '.zsh': '#',
    '.fish': '#',
    '.rb': '#',
    '.pl': '#',
    '.ps1': '#',
    
    # C-style languages
    '.js': '//',
    '.ts': '//',
    '.jsx': '//',
    '.tsx': '//',
    '.c': '//',
    '.cpp': '//',
    '.cxx': '//',
    '.cc': '//',
    '.h': '//',
    '.hpp': '//',
    '.cs': '//',
    '.java': '//',
    '.php': '//',
    '.go': '//',
    '.rs': '//',
    
    # Configuration files
    '.conf': '#',
    '.cfg': '#',
    '.ini': ';',
    '.toml': '#',
    '.yaml': '#',
    '.yml': '#',
    '.json': '//',  # JSON doesn't have comments, but some tools use // 
    
    # Web
    '.html': '<!--',
    '.xml': '<!--',
    '.css': '/*',
    
    # Database
    '.sql': '--',
    
    # Other
    '.vim': '"',
    '.vimrc': '"',
    '.gitignore': '#',
    '.dockerfile': '#',
    '.dockerignore': '#',
}

def detect_comment_prefix(filename):
    """Detect comment prefix based on file extension."""
    if not filename:
        return None
        
    # Get file extension
    _, ext = os.path.splitext(filename.lower())
    
    # Handle special cases
    if filename.lower().endswith('dockerfile'):
        return '#'
    if filename.lower().endswith('makefile'):
        return '#'
        
    return COMMENT_PREFIXES.get(ext, None)

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 comment_detector.py <filename>")
        sys.exit(1)
        
    filename = sys.argv[1]
    prefix = detect_comment_prefix(filename)
    
    if prefix:
        print(f"Comment prefix for {filename}: {prefix}")
    else:
        print(f"No comment prefix detected for {filename}")
        print("Supported extensions:", ', '.join(sorted(COMMENT_PREFIXES.keys())))

if __name__ == "__main__":
    main()
