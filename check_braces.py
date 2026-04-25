import sys

def check_balance(filename):
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
    
    stack = []
    pairs = {'(': ')', '{': '}', '[': ']'}
    for i, char in enumerate(content):
        if char in '({[':
            stack.append((char, i))
        elif char in ')}]':
            if not stack:
                print(f"Extra closing '{char}' at position {i}")
                # Print context
                start = max(0, i-20)
                end = min(len(content), i+20)
                print(f"Context: {content[start:end]}")
                return
            top, pos = stack.pop()
            if pairs[top] != char:
                print(f"Mismatched '{char}' at position {i}, expected '{pairs[top]}' to match '{top}' from position {pos}")
                # Print context
                start = max(0, i-20)
                end = min(len(content), i+20)
                print(f"Context: {content[start:end]}")
                return
    
    if stack:
        for char, pos in stack:
            print(f"Unclosed '{char}' from position {pos}")
            # Print context
            start = max(0, pos-20)
            end = min(len(content), pos+20)
            print(f"Context: {content[start:end]}")
    else:
        print("Balanced!")

if __name__ == "__main__":
    check_balance(sys.argv[1])
