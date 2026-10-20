# Below is the code to bring in two built-in Python tools: json reads the rule files,
# and Path finds files and folders the same way on Windows, Mac and Linux.
import json
from pathlib import Path

# Below is the code to say where the rule files live (the "rules" folder next to this file)
# and which text fields every rule must have. The "steps" list is checked separately.
RULES_DIR = Path(__file__).parent / "rules"
TEXT_FIELDS = ("id", "category", "symptom")


# Below is the code to check one rule against our rule format (the rule schema).
# It returns a list of problems, so an empty list means the rule is fine.
def check_rule(rule):
    if not isinstance(rule, dict):
        return ["each rule must be an object with id, category, symptom and steps"]
    problems = []
    for field in TEXT_FIELDS:
        value = rule.get(field)
        if not isinstance(value, str) or not value.strip():
            problems.append(f"'{field}' must be filled in with text")
    steps = rule.get("steps")
    if not isinstance(steps, list) or not steps or not all(isinstance(step, str) and step.strip() for step in steps):
        problems.append("'steps' must be a list with at least one text step")
    return problems


# Below is the code to read every .json file in the rules folder and check each rule inside it.
# If anything is wrong (broken file, missing field, repeated id) it stops and lists every problem found.
def load_rules(folder=RULES_DIR):
    rules, problems, seen_ids = [], [], set()
    for path in sorted(Path(folder).glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            problems.append(f"{path.name}: not valid JSON ({error})")
            continue
        if not isinstance(data, list):
            problems.append(f"{path.name}: the file must hold a list of rules")
            continue
        for number, rule in enumerate(data, start=1):
            rule_problems = check_rule(rule)
            if not rule_problems and rule["id"] in seen_ids:
                rule_problems.append(f"id '{rule['id']}' is used more than once")
            if rule_problems:
                problems += [f"{path.name}, rule {number}: {problem}" for problem in rule_problems]
            else:
                seen_ids.add(rule["id"])
                rules.append(rule)
    if not rules:
        problems.append(f"no valid rules found in {folder}")
    if problems:
        raise ValueError("\n".join(problems))
    return rules


# Below is the code to list the categories in the order they first appear, with no repeats.
def categories(rules):
    return list(dict.fromkeys(rule["category"] for rule in rules))


# Below is the code to get every rule (one per symptom) that belongs to a single category.
def rules_in_category(rules, category):
    return [rule for rule in rules if rule["category"] == category]


# Below is the code to find one rule by its id. It gives back None when the id does not exist,
# which is how the app rejects unknown symptoms.
def find_rule(rules, rule_id):
    return next((rule for rule in rules if rule["id"] == rule_id), None)


# Below is the code to run the rule schema check that the pipeline starts with "python rules.py".
# It prints a summary and returns 0 when every rule is valid, or prints the problems and returns 1.
def main(folder=RULES_DIR):
    try:
        rules = load_rules(folder)
    except ValueError as error:
        print(f"Rule check FAILED:\n{error}")
        return 1
    print(f"Rule check passed: {len(rules)} rules in {len(categories(rules))} categories")
    return 0


# Below is the code to run main() only when this file is started directly, not when the app imports it.
# The number main() returns becomes the exit code, so a failed check makes the pipeline step fail.
if __name__ == "__main__":
    raise SystemExit(main())
