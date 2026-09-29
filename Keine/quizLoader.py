import json
import os

def load_quiz_data(file_path):
    # Loads quiz questions.
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"The file '{file_path}' could not be found.")
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            if not isinstance(data, list) or len(data) == 0:
                raise ValueError("JSON file must contain a non-empty list of questions.")
            return data
    except json.JSONDecodeError:
        raise ValueError(f"Failed to parse JSON from '{file_path}'. Check your file formatting.")