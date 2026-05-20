#!/usr/bin/env python3
"""
Script to remove all 'service_entries' arrays from a JSON file.
This script recursively searches through the JSON structure and removes
all occurrences of 'service_entries' while maintaining valid JSON format.

Usage:
    python remove_service_entries.py <input_file> [output_file]
    
Arguments:
    input_file   : Path to the JSON file to process
    output_file  : (Optional) Path to save the cleaned JSON. 
                   If not provided, the input file will be overwritten.

Examples:
    python remove_service_entries.py data.json
    python remove_service_entries.py data.json cleaned_data.json
"""

import json
import sys
import os
from pathlib import Path


def remove_service_entries(obj):
    """
    Recursively remove 'service_entries' from all levels of the JSON structure.
    
    Args:
        obj: The JSON object (dict or list) to process
        
    Returns:
        The modified object with all 'service_entries' removed
    """
    if isinstance(obj, dict):
        # Remove service_entries if it exists
        if 'service_entries' in obj:
            del obj['service_entries']
        # Recursively process all values
        for key, value in obj.items():
            remove_service_entries(value)
    elif isinstance(obj, list):
        # Recursively process all items in the list
        for item in obj:
            remove_service_entries(item)
    return obj


def process_json_file(input_file, output_file=None):
    """
    Process a JSON file to remove all 'service_entries' arrays.
    
    Args:
        input_file: Path to the input JSON file
        output_file: Path to the output JSON file (optional)
    """
    # Check if input file exists
    if not os.path.exists(input_file):
        print(f"Error: Input file '{input_file}' does not exist.")
        sys.exit(1)
    
    # If no output file specified, overwrite the input file
    if output_file is None:
        output_file = input_file
        print(f"Processing: {input_file}")
        print("Note: File will be overwritten with cleaned data.")
    else:
        print(f"Processing: {input_file}")
        print(f"Output will be saved to: {output_file}")
    
    try:
        # Read the JSON file
        print("Reading JSON file...")
        with open(input_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # Count service_entries before removal
        count = count_service_entries(data)
        print(f"Found {count} 'service_entries' arrays in the JSON structure.")
        
        # Remove all service_entries
        print("Removing 'service_entries' arrays...")
        cleaned_data = remove_service_entries(data)
        
        # Write back to file
        print("Writing cleaned JSON to file...")
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(cleaned_data, f, indent=4)
        
        # Get file sizes
        input_size = os.path.getsize(input_file)
        output_size = os.path.getsize(output_file)
        size_reduction = input_size - output_size
        
        print("\n✓ Success!")
        print(f"  Original size: {input_size:,} bytes")
        print(f"  New size: {output_size:,} bytes")
        if size_reduction > 0:
            print(f"  Size reduction: {size_reduction:,} bytes ({size_reduction/input_size*100:.1f}%)")
        print(f"  All 'service_entries' arrays have been removed.")
        
    except json.JSONDecodeError as e:
        print(f"\nError: Invalid JSON format in '{input_file}'")
        print(f"Details: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"\nError: {e}")
        sys.exit(1)


def count_service_entries(obj):
    """
    Count the number of 'service_entries' in the JSON structure.
    
    Args:
        obj: The JSON object to search
        
    Returns:
        Count of 'service_entries' found
    """
    count = 0
    if isinstance(obj, dict):
        if 'service_entries' in obj:
            count += 1
        for value in obj.values():
            count += count_service_entries(value)
    elif isinstance(obj, list):
        for item in obj:
            count += count_service_entries(item)
    return count


def main():
    """Main function to handle command-line arguments and execute the script."""
    # Check command-line arguments
    if len(sys.argv) < 2:
        print("Error: Missing required argument.")
        print("\nUsage:")
        print("  python remove_service_entries.py <input_file> [output_file]")
        print("\nExamples:")
        print("  python remove_service_entries.py data.json")
        print("  python remove_service_entries.py data.json cleaned_data.json")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    
    # Process the file
    process_json_file(input_file, output_file)


if __name__ == "__main__":
    main()
