import re
import sys

def calculate_cyclomatic_complexity(java_code):

    java_code = re.sub(r'//.*', '', java_code)
    java_code = re.sub(r'/\*.*?\*/', '', java_code, flags=re.DOTALL)
    java_code = re.sub(r'".*?"', '""', java_code)

    decision_patterns = [
        r'\bif\b',
        r'\belse\s+if\b',
        r'\bfor\b',
        r'\bwhile\b',
        r'\bdo\b',
        r'\bcase\b',
        r'\bcatch\b',
        r'\?\s*',
        r'&&',
        r'\|\|',
    ]

    method_pattern = re.compile(
        r'(?:(?:public|private|protected|static|final|synchronized|abstract)\s+)*'
        r'(?:\w+(?:<.*?>)?)\s+'
        r'(\w+)\s*\('
        r'[^)]*\)\s*'
        r'(?:throws\s+\w+(?:\s*,\s*\w+)*)?\s*'
        r'\{'
    )

    results = {}
    methods = list(method_pattern.finditer(java_code))

    if not methods:
        complexity = 1

        for pattern in decision_patterns:
            complexity += len(re.findall(pattern, java_code))

        results['[entire file]'] = complexity

        return results
    
    for method_match in methods:
        method_name = method_match.group(1)
        start = method_match.end() - 1
        brace_count = 0
        end = start

        for j, char in enumerate(java_code[start:], start):
            if char == '{':
                brace_count += 1
            elif char == '}':
                brace_count -= 1
                if brace_count == 0:
                    end = j
                    break

        method_body = java_code[start:end+1]
        complexity = 1

        for pattern in decision_patterns:
            complexity += len(re.findall(pattern, method_body))

        key = method_name
        count = 1

        while key in results:
            key = f"{method_name}_{count}"
            count += 1
        results[key] = complexity

    return results

# python cc_calculator.py <path_to_java_file>
if __name__ == "__main__":
    with open(sys.argv[1], 'r') as file:
        java_code = file.read()
        
    results = calculate_cyclomatic_complexity(java_code)

    for method, complexity in results.items():
        print(f"{method}: {complexity}")