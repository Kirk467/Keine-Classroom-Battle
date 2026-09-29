import glob
import os

def select_json_file():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    json_files = glob.glob(os.path.join(script_dir, "*.json"))
    
    print("\n" + "="*40)
    print("         SELECT A QUIZ FILE           ")
    print("="*40)
    
    if not json_files:
        print("No JSON files found in the folder.")
        custom_path = input("Enter the path to your JSON quiz file manually: ").strip()
        return custom_path
    
    print("Available JSON files:")
    for idx, file_path in enumerate(json_files, 1):
        print(f"  {idx}. {os.path.basename(file_path)}")
    print("  C. Enter a custom file path")
    print("-" * 40)
    
    while True:
        choice = input("Select an option (number or 'C')...: ").strip()
        
        if choice.upper() == 'C':
            return input("Enter the path to your JSON quiz file: ").strip()
        
        if choice.isdigit():
            idx = int(choice) - 1
            if 0 <= idx < len(json_files):
                return json_files[idx] 
        
        print("Invalid selection. Please enter a valid number from the list or 'C'.")