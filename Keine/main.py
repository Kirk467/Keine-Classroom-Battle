from fileHandler import select_json_file
from quizLoader import load_quiz_data
from quizEngine import run_quiz

def main():
    file_path = select_json_file()
    
    questions = load_quiz_data(file_path)
    
    run_quiz(questions)

if __name__ == "__main__":
    main()