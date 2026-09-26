---
applyTo: "**"
description: "Mandates real, executable code generation—no placeholders or dummy segments."
---

# Code Generation and Real Values over Placeholders Instructions

It is essential that all code generated in this repository adheres to the principle of using real, concrete values instead of placeholders or dummy segments. This guideline ensures that all code is immediately executable and functional, testable, and maintainable, enhancing the reliability and quality of our codebase.

## Project Context

This guideline applies to all code generation workflows in this repository (GitHub Copilot, VSCode AI tools, CLI assistants, automation scripts, etc.) and targets every programming language and scripting environment, including but not limited to: TypeScript, JavaScript, Python, Bash, C#, and configuration files (both JSON and YAML).

## Objective

Ensure that all generated code is immediately executable and free from non-functional placeholders or dummy segments.

## Core Rules

1. **Executable Code Only**
   All generated code must be valid and directly runnable. No placeholder values or "dummy" code that would break logic or execution.

2. **Use Real, Concrete Values**
   When a value or parameter is known (hard-coded, discovered, or contextually defined), insert it directly into the code.

3. **Use Parametric Syntax Only When Necessary**
   Only use parameters when the code legitimately requires dynamic input. Use the idiomatic approach for each language:
   - **Bash**: `${VARIABLE}` or `$VARIABLE` for environment variables
   - **Python**: Function parameters, keyword arguments, or configuration objects
   - **TypeScript/JavaScript**: Function parameters, destructured arguments, or configuration objects
   - **C#**: Method parameters, constructor injection, configuration providers (`IConfiguration`, `IOptions<T>`), or `appsettings.json` values

4. **Never Output Unusable or Dummy Blocks**
   Avoid segments such as:
   - Generic comments: `# your_value_here`, `// TODO: fill this in`, `<!-- PLACEHOLDER -->`
   - Pseudo-code markers: `<TO_BE_FILLED>`, `[INSERT_VALUE]`, `***REPLACE_ME***`
   - Non-functional defaults: `"dummy"`, `"test"`, `"foo"`, `"bar"` (unless legitimately required for examples or tests)
   - Empty or commented-out placeholder lines that serve no functional purpose

   Every line must serve a clear, functional purpose.

5. **Enforce Cross-Language Compliance**
   Apply these instructions for every language. Adopt the idiomatic way to represent parameters when required (e.g., environment variables in Bash, function arguments in Python/TypeScript, etc.).
   - **TypeScript/JavaScript**: Use function parameters, environment variables (`process.env`), or configuration modules
   - **Python**: Use function parameters, environment variables (`os.environ`), or config files
   - **Bash**: Use environment variables (`$VAR` or `${VAR}`) or command-line arguments (`$1`, `$2`)
   - **C#**: Use method parameters (including `Main(string[] args)` for CLI apps), environment variables via `Environment.GetEnvironmentVariable`, and configuration/option classes (for example, the 'Options Pattern' in .NET).

6. **Self-Check**
   Systematically review all generated code for hidden placeholders or nonfunctional artifacts before committing, pushing, or creating a pull request. Ask yourself:
   - Can this code run without modification?
   - Are all values either concrete or properly parameterized?
   - Would another developer need to "fill in" anything before using this code?

## Expected Result

- No output contains non-functional placeholders or "dummy" variables.
- All generated code is ready-to-run or usable as a real function/module/script.
- Code follows its proper language best practices for configuration, dependency injection, and type safety.
- Refactoring, automation, and team workflows become more reliable and less error-prone.
- Consistent, high-quality code generation across all developer tools and workflows.

## Applicability

**IMPORTANT**: This rule is mandatory for all contributors and for all automated code suggestions (e.g., Copilot, VSCode AI, CI codegen steps).

**NOTE**: If a value is not known at generation time but is required, use the idiomatic parametric form for the target language. **Never a fake placeholder**.

> **When in doubt, prefer the simpler approach, ask the user or request better specifications**
