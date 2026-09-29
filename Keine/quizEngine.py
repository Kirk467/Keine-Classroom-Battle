import random

def run_quiz(questions):
    random.shuffle(questions)
    
    score = 0
    total_questions = len(questions)
    missed_questions = []

    print("\n" + "=" * 40)
    print("      WELCOME TO THE PYTHON QUIZ GAME!      ")
    print("=" * 40)
    print(f"Total Questions: {total_questions}\n")

    for i, q in enumerate(questions, 1):
        print(f"Question {i}: {q['question']}")
        
        # Shuffle answer options
        options = q['options'].copy()
        correct_answer = q['answer']
        random.shuffle(options)
        
        # Map letters to shuffled options
        letter_mapping = {}
        for idx, option in enumerate(options):
            letter = chr(65 + idx)
            letter_mapping[letter] = option
            print(f"  {letter}. {option}")
            
        # Get and validate user input
        while True:
            user_choice = input("\nYour answer (enter letter): ").strip().upper()
            if user_choice in letter_mapping:
                break
            print("Invalid input. Please enter a letter corresponding to the available options.")
            
        # Evaluate answer
        chosen_answer = letter_mapping[user_choice]
        if chosen_answer == correct_answer:
            print("Correct!\n" + "-"*30)
            score += 1
        else:
            print(f"Incorrect. The correct answer was: {correct_answer}\n" + "-"*30)
            missed_questions.append(q)

    percentage = (score / total_questions) * 100
    print("\n" + "="*40)
    print("             QUIZ FINISHED!             ")
    print("="*40)
    print(f"Final Score: {score}/{total_questions} ({percentage:.1f}%)\n")

    if missed_questions:
        retry = input("\nWould you like to review and retry the questions you missed? (y/n): ").strip().lower()
        if retry == 'y':
            print("\n" + "~"*40)
            print("         RETRYING MISSED QUESTIONS         ")
            print("~"*40)
            run_quiz(missed_questions)